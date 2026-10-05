import 'package:flutter_test/flutter_test.dart';
import 'package:orama_fabrica2/api/api_client.dart';
import 'package:orama_fabrica2/auth/auth_store.dart';

import '../support/servidor_falso.dart';

void main() {
  test('entrar guarda a sessão e coloca o token nas próximas chamadas', () async {
    final m = montar();
    m.servidor.responder('POST', '/auth/login', loginJson());
    m.servidor.responder('GET', '/catalogo', catalogoJson());
    final auth = m.deps.auth;

    await auth.entrar('func1', 'senha-123');

    expect(auth.estado, EstadoAuth.logado);
    expect(auth.usuario!.nome, 'Funcionária');
    expect(auth.podeLancar, isTrue);
    expect(m.secure.dados['token'], 'token-abc');
    expect(m.servidor.chamadas('POST', '/auth/login').single.corpo, {'login': 'func1', 'senha': 'senha-123'});

    await m.deps.api.catalogo();
    expect(m.servidor.chamadas('GET', '/catalogo').single.cabecalhos['Authorization'], 'Bearer token-abc');
  });

  test('senha errada lança ApiException e não cria sessão', () async {
    final m = montar();
    m.servidor.rota('POST', '/auth/login', (_) => problema(401, 'credenciais_invalidas', 'Login ou senha incorretos.'));

    await expectLater(m.deps.auth.entrar('func1', 'errada'), throwsA(isA<ApiException>()));

    expect(m.deps.auth.logado, isFalse);
    expect(m.secure.dados, isEmpty);
  });

  test('sem conexão no login lança SemConexaoException', () async {
    final m = montar();
    m.servidor.offline = true;

    await expectLater(m.deps.auth.entrar('func1', 'x'), throwsA(isA<SemConexaoException>()));
  });

  test('restaurar recupera a sessão salva sem chamar a API', () async {
    final primeiro = montar();
    primeiro.servidor.responder('POST', '/auth/login', loginJson());
    await primeiro.deps.auth.entrar('func1', 'senha-123');

    final segundo = montar(secure: primeiro.secure);
    await segundo.deps.auth.restaurar();

    expect(segundo.deps.auth.estado, EstadoAuth.logado);
    expect(segundo.deps.auth.usuario!.login, 'func1');
    expect(segundo.servidor.requisicoes, isEmpty);
    expect(segundo.deps.client.token, 'token-abc');
  });

  test('restaurar sem sessão salva cai para deslogado', () async {
    final m = montar();

    await m.deps.auth.restaurar();

    expect(m.deps.auth.estado, EstadoAuth.deslogado);
  });

  test('sessão com token vencido não é restaurada e é apagada', () async {
    final m = montar();
    m.servidor.responder('POST', '/auth/login', loginJson());
    await m.deps.auth.entrar('func1', 'senha-123');

    final depois = montar(secure: m.secure);
    // o relógio do app está 13 horas à frente: o token de 12 h já venceu
    final auth = AuthStore(depois.deps.api, depois.deps.client, m.secure,
        agora: () => DateTime.now().add(const Duration(hours: 13)));
    await auth.restaurar();

    expect(auth.estado, EstadoAuth.deslogado);
    expect(m.secure.dados, isEmpty);
  });

  test('dado salvo corrompido cai para deslogado em vez de travar', () async {
    final m = montar();
    m.secure.dados['token'] = 't';
    m.secure.dados['usuario'] = '{isto não é json';
    m.secure.dados['expira_em'] = DateTime.now().add(const Duration(hours: 1)).toUtc().toIso8601String();

    await m.deps.auth.restaurar();

    expect(m.deps.auth.estado, EstadoAuth.deslogado);
    expect(m.secure.dados, isEmpty);
  });

  test('sair apaga tudo da sessão', () async {
    final m = montar();
    m.servidor.responder('POST', '/auth/login', loginJson());
    await m.deps.auth.entrar('func1', 'senha-123');

    await m.deps.auth.sair();

    expect(m.deps.auth.estado, EstadoAuth.deslogado);
    expect(m.deps.auth.usuario, isNull);
    expect(m.deps.client.token, isNull);
    expect(m.secure.dados, isEmpty);
  });

  test('o servidor recusar o token (401) derruba a sessão sozinho', () async {
    final m = montar();
    m.servidor.responder('POST', '/auth/login', loginJson());
    m.servidor.rota('GET', '/catalogo', (_) => problema(401, 'nao_autorizado', 'x'));
    await m.deps.auth.entrar('func1', 'senha-123');

    await expectLater(m.deps.api.catalogo(), throwsA(isA<ApiException>()));
    await Future<void>.delayed(Duration.zero);

    expect(m.deps.auth.estado, EstadoAuth.deslogado);
    expect(m.secure.dados, isEmpty);
  });

  test('papéis: só administrador e fábrica lançam; leitura só consulta; loja nem isso', () async {
    for (final caso in [('admin', true, true), ('fabrica', true, true), ('leitura', false, true), ('loja', false, false)]) {
      final m = montar();
      m.servidor.responder('POST', '/auth/login', loginJson(usuario: {...usuarioFabricaJson, 'papel': caso.$1}));
      await m.deps.auth.entrar('x', 'y');
      expect(m.deps.auth.podeLancar, caso.$2, reason: caso.$1);
      expect(m.deps.auth.usuario!.podeConsultar, caso.$3, reason: caso.$1);
    }
  });
}
