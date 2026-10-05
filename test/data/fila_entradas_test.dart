import 'package:flutter_test/flutter_test.dart';
import 'package:orama_fabrica2/data/entrada_pendente.dart';
import 'package:orama_fabrica2/data/fila_entradas.dart';

import '../support/servidor_falso.dart';

EntradaPendente linha(String id, {String usuario = 'u1', String quantidade = '12', String? erro}) => EntradaPendente(
      id: id,
      usuarioId: usuario,
      itemId: 'it-cookie',
      itemNome: 'BROWNIE',
      quantidade: quantidade,
      unidade: 'un',
      origem: 'producao',
      ocorridoEm: DateTime.utc(2026, 10, 4, 12),
      erro: erro,
    );

Map<String, Object?> resultado(String id, String status, {String? erro, String? etiqueta}) =>
    {'id': id, 'status': status, 'etiqueta': etiqueta, 'qtdBase': 12, 'erro': erro};

void main() {
  late Montagem m;
  late FilaEntradas fila;

  setUp(() {
    m = montar();
    fila = m.deps.fila;
  });

  void servidorAceita() => m.servidor.rota('POST', '/entradas', (r) {
        final itens = (r.corpo['itens'] as List).cast<Map<String, dynamic>>();
        return json({'loteEnvioId': 'x', 'resultados': [for (final i in itens) resultado(i['id'] as String, 'criado')]});
      });

  test('linhas aceitas saem da fila', () async {
    servidorAceita();
    await fila.adicionar([linha('a'), linha('b')]);

    final r = await fila.enviar('u1');

    expect((r.enviadas, r.recusadas, r.indisponivel), (2, 0, false));
    expect(fila.doUsuario('u1'), isEmpty);
    expect(m.store.dados[FilaEntradas.chave], '[]');
  });

  test('o corpo enviado tem o formato da API (id, quantidade numérica, data em UTC)', () async {
    servidorAceita();
    await fila.adicionar([linha('a', quantidade: '3.85')]);

    await fila.enviar('u1');

    final item = (m.servidor.chamadas('POST', '/entradas').single.corpo['itens'] as List).single as Map;
    expect(item['id'], 'a');
    expect(item['itemId'], 'it-cookie');
    expect(item['quantidade'], 3.85);
    expect(item['unidade'], 'un');
    expect(item['origem'], 'producao');
    expect(item['ocorridoEm'], '2026-10-04T12:00:00.000Z');
    expect(item.containsKey('lote'), isFalse);
  });

  test('ja_registrado (reenvio) também tira da fila', () async {
    m.servidor.rota('POST', '/entradas', (r) => json({'resultados': [resultado('a', 'ja_registrado', etiqueta: 'R000001')]}));
    await fila.adicionar([linha('a')]);

    final r = await fila.enviar('u1');

    expect(r.enviadas, 1);
    expect(fila.doUsuario('u1'), isEmpty);
  });

  test('linha recusada fica com o motivo e NÃO é reenviada sozinha', () async {
    m.servidor.rota('POST', '/entradas', (r) => json({'resultados': [resultado('a', 'recusado', erro: 'Informe o lote.')]}));
    await fila.adicionar([linha('a')]);

    final r = await fila.enviar('u1');

    expect(r.recusadas, 1);
    expect(fila.doUsuario('u1').single.erro, 'Informe o lote.');
    expect(fila.aguardando('u1'), 0);
    expect(fila.recusadas('u1'), 1);

    final denovo = await fila.enviar('u1');
    expect(denovo.enviadas + denovo.recusadas, 0);
    expect(m.servidor.chamadas('POST', '/entradas'), hasLength(1));
  });

  test('tentarNovamente devolve a linha recusada para o próximo envio', () async {
    await fila.adicionar([linha('a', erro: 'Informe o lote.')]);

    await fila.tentarNovamente('a');

    expect(fila.aguardando('u1'), 1);
    expect(fila.doUsuario('u1').single.erro, isNull);
  });

  test('sem conexão: nada se perde e o resultado avisa', () async {
    m.servidor.offline = true;
    await fila.adicionar([linha('a'), linha('b')]);

    final r = await fila.enviar('u1');

    expect(r.indisponivel, isTrue);
    expect(fila.aguardando('u1'), 2);
    expect(fila.enviando, isFalse);
  });

  test('servidor com erro 500 também mantém tudo na fila', () async {
    m.servidor.rota('POST', '/entradas', (_) => problema(500, 'erro_interno', 'Erro interno.'));
    await fila.adicionar([linha('a')]);

    final r = await fila.enviar('u1');

    expect(r.indisponivel, isTrue);
    expect(fila.aguardando('u1'), 1);
  });

  test('401 mantém a fila (a sessão cai, mas o lançamento fica guardado)', () async {
    m.servidor.rota('POST', '/entradas', (_) => problema(401, 'nao_autorizado', 'x'));
    await fila.adicionar([linha('a')]);

    await fila.enviar('u1');

    expect(fila.aguardando('u1'), 1);
  });

  test('pedido inteiro recusado (403 sem permissão) marca as linhas com o motivo', () async {
    m.servidor.rota('POST', '/entradas', (_) => problema(403, 'acesso_negado', 'Você não tem permissão para isso.'));
    await fila.adicionar([linha('a'), linha('b')]);

    final r = await fila.enviar('u1');

    expect(r.recusadas, 2);
    expect(fila.doUsuario('u1').map((e) => e.erro), everyElement('Você não tem permissão para isso.'));
  });

  test('envia em lotes de 100 linhas', () async {
    servidorAceita();
    await fila.adicionar([for (var i = 0; i < 250; i++) linha('l$i')]);

    final r = await fila.enviar('u1');

    expect(r.enviadas, 250);
    final chamadas = m.servidor.chamadas('POST', '/entradas');
    expect(chamadas.map((c) => (c.corpo['itens'] as List).length), [100, 100, 50]);
  });

  test('um lote que falha por falta de conexão preserva os lotes seguintes', () async {
    var chamada = 0;
    m.servidor.rota('POST', '/entradas', (r) {
      chamada++;
      if (chamada == 2) return problema(500, 'erro_interno', 'x');
      final itens = (r.corpo['itens'] as List).cast<Map<String, dynamic>>();
      return json({'resultados': [for (final i in itens) resultado(i['id'] as String, 'criado')]});
    });
    await fila.adicionar([for (var i = 0; i < 150; i++) linha('l$i')]);

    final r = await fila.enviar('u1');

    expect(r.enviadas, 100);
    expect(r.indisponivel, isTrue);
    expect(fila.aguardando('u1'), 50);
  });

  test('só envia as linhas do usuário logado; as de outro continuam guardadas', () async {
    servidorAceita();
    await fila.adicionar([linha('a', usuario: 'u1'), linha('b', usuario: 'u2')]);

    await fila.enviar('u1');

    expect(fila.doUsuario('u1'), isEmpty);
    expect(fila.doUsuario('u2'), hasLength(1));
    final ids = (m.servidor.chamadas('POST', '/entradas').single.corpo['itens'] as List).map((i) => i['id']);
    expect(ids, ['a']);
  });

  test('resposta incompleta deixa a linha na fila para tentar de novo', () async {
    m.servidor.rota('POST', '/entradas', (r) => json({'resultados': [resultado('a', 'criado')]}));
    await fila.adicionar([linha('a'), linha('b')]);

    final r = await fila.enviar('u1');

    expect(r.enviadas, 1);
    expect(fila.doUsuario('u1').single.id, 'b');
  });

  test('dois envios ao mesmo tempo: só um vai ao servidor', () async {
    servidorAceita();
    await fila.adicionar([linha('a')]);

    final resultados = await Future.wait([fila.enviar('u1'), fila.enviar('u1')]);

    expect(resultados.where((r) => r.ocupado), hasLength(1));
    expect(m.servidor.chamadas('POST', '/entradas'), hasLength(1));
  });

  test('descartar remove a linha', () async {
    await fila.adicionar([linha('a'), linha('b')]);

    await fila.descartar('a');

    expect(fila.doUsuario('u1').map((e) => e.id), ['b']);
  });

  test('a fila sobrevive a fechar o app (persistência)', () async {
    await fila.adicionar([linha('a', quantidade: '3.85', erro: 'Informe o lote.')]);

    final reaberta = montar(store: m.store).deps.fila;

    final e = reaberta.doUsuario('u1').single;
    expect((e.id, e.quantidade, e.erro, e.ocorridoEm.toUtc()), ('a', '3.85', 'Informe o lote.', DateTime.utc(2026, 10, 4, 12)));
  });

  test('fila ilegível no armazenamento não derruba o app', () {
    m.store.dados[FilaEntradas.chave] = '{quebrado';

    final reaberta = montar(store: m.store).deps.fila;

    expect(reaberta.doUsuario('u1'), isEmpty);
    expect(m.store.dados[FilaEntradas.chave], '{quebrado', reason: 'o conteúdo original não é apagado');
  });
}
