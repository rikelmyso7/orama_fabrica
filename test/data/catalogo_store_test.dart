import 'package:flutter_test/flutter_test.dart';
import 'package:orama_fabrica2/data/catalogo_store.dart';

import '../support/servidor_falso.dart';

void main() {
  test('atualizar traz o catálogo e guarda no aparelho', () async {
    final m = montar();
    m.servidor.responder('GET', '/catalogo', catalogoJson());
    final store = m.deps.catalogo;

    await store.atualizar();

    expect(store.catalogo!.itens, hasLength(3));
    expect(store.aviso, isNull);
    expect(m.store.dados[CatalogoStore.chave], contains('COCADA'));
  });

  test('sem conexão e com cache, usa o catálogo salvo e avisa', () async {
    final primeiro = montar();
    primeiro.servidor.responder('GET', '/catalogo', catalogoJson());
    await primeiro.deps.catalogo.atualizar();

    final segundo = montar(store: primeiro.store);
    segundo.servidor.offline = true;
    await segundo.deps.catalogo.atualizar();

    expect(segundo.deps.catalogo.catalogo!.itens, hasLength(3));
    expect(segundo.deps.catalogo.aviso, contains('catálogo salvo'));
  });

  test('sem conexão e sem cache, avisa que não há itens', () async {
    final m = montar();
    m.servidor.offline = true;

    await m.deps.catalogo.atualizar();

    expect(m.deps.catalogo.catalogo, isNull);
    expect(m.deps.catalogo.aviso, contains('sem catálogo salvo'));
  });

  test('erro da API vira aviso e mantém o que havia', () async {
    final m = montar();
    m.servidor.responder('GET', '/catalogo', catalogoJson());
    await m.deps.catalogo.atualizar();
    m.servidor.rota('GET', '/catalogo', (_) => problema(500, 'erro_interno', 'Erro interno. Tente novamente.'));

    await m.deps.catalogo.atualizar();

    expect(m.deps.catalogo.aviso, 'Erro interno. Tente novamente.');
    expect(m.deps.catalogo.catalogo, isNotNull);
  });

  test('cache ilegível é ignorado', () {
    final m = montar();
    m.store.dados[CatalogoStore.chave] = '{quebrado';

    final store = montar(store: m.store).deps.catalogo;

    expect(store.catalogo, isNull);
    expect(store.precisaAtualizar, isTrue);
  });

  test('precisaAtualizar: sem catálogo ou depois de 1 hora', () async {
    var agora = DateTime(2026, 10, 4, 10);
    final m = montar();
    final store = CatalogoStore(m.deps.api, m.store, agora: () => agora);
    expect(store.precisaAtualizar, isTrue);
    m.servidor.responder('GET', '/catalogo', catalogoJson());

    await store.atualizar();
    expect(store.precisaAtualizar, isFalse);

    agora = agora.add(const Duration(minutes: 59));
    expect(store.precisaAtualizar, isFalse);
    agora = agora.add(const Duration(minutes: 2));
    expect(store.precisaAtualizar, isTrue);
  });

  test('busca por categoria e por texto, sem acento e em ordem alfabética', () async {
    final m = montar();
    m.servidor.responder('GET', '/catalogo', catalogoJson());
    await m.deps.catalogo.atualizar();
    final store = m.deps.catalogo;

    expect(store.itens().map((i) => i.nome), ['BROWNIE', 'CASTANHA GLACEADA', 'COCADA']);
    expect(store.itens(categoriaId: 'cat-baldes').map((i) => i.nome), ['COCADA']);
    expect(store.itens(busca: 'castanha').map((i) => i.nome), ['CASTANHA GLACEADA']);
    expect(store.itens(busca: 'glaceada', categoriaId: 'cat-cookies'), isEmpty);
    expect(store.catalogo!.local('loc-oficina')!.nome, 'Oficina');
    expect(store.catalogo!.item('it-balde')!.controlaRecipiente, isTrue);
    expect(store.catalogo!.item('nao-existe'), isNull);
  });
}
