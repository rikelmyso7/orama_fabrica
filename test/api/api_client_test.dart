import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:orama_fabrica2/api/api_client.dart';

import '../support/servidor_falso.dart';

void main() {
  late ServidorFalso servidor;
  late ApiClient client;

  setUp(() {
    servidor = ServidorFalso();
    client = ApiClient(baseUrl: 'http://teste.local/', client: servidor.client);
  });

  test('envia o token no cabeçalho e lê JSON com acento', () async {
    servidor.responder('GET', '/catalogo', {'nome': 'Câmara frigorífica'});
    client.token = 'abc';

    final r = await client.get('/catalogo');

    expect(r['nome'], 'Câmara frigorífica');
    expect(servidor.requisicoes.single.cabecalhos['Authorization'], 'Bearer abc');
  });

  test('não envia Authorization sem token, nem no login', () async {
    servidor.responder('POST', '/auth/login', {'ok': true});

    await client.post('/auth/login', corpo: {'login': 'a', 'senha': 'b'}, autenticado: false);

    expect(servidor.requisicoes.single.cabecalhos.containsKey('Authorization'), isFalse);
    expect(servidor.requisicoes.single.cabecalhos['Content-Type'], contains('application/json'));
  });

  test('envia filtros na query', () async {
    servidor.responder('GET', '/movimentos', []);

    await client.get('/movimentos', query: {'de': '2026-10-04', 'limite': '50'});

    expect(servidor.requisicoes.single.uri.queryParameters, {'de': '2026-10-04', 'limite': '50'});
  });

  test('resposta 204 devolve null', () async {
    servidor.rota('POST', '/x', (_) => http.Response('', 204));

    expect(await client.post('/x'), isNull);
  });

  test('erro da API vira ApiException com código e mensagem em português', () async {
    servidor.rota('POST', '/x', (_) => problema(403, 'senha_invalida', 'Senha de administrador incorreta.'));

    await expectLater(
      client.post('/x'),
      throwsA(isA<ApiException>()
          .having((e) => e.status, 'status', 403)
          .having((e) => e.codigo, 'codigo', 'senha_invalida')
          .having((e) => e.mensagem, 'mensagem', 'Senha de administrador incorreta.')),
    );
  });

  test('guarda os campos extras do erro (por exemplo, até quando está bloqueado)', () async {
    servidor.rota('POST', '/x', (_) => problema(429, 'bloqueado', 'Muitas tentativas.', extras: {'bloqueadoAte': '2026-10-04T10:00:00Z'}));

    try {
      await client.post('/x');
      fail('deveria lançar');
    } on ApiException catch (e) {
      expect(e.extras['bloqueadoAte'], '2026-10-04T10:00:00Z');
    }
  });

  test('erro que não é JSON (página de proxy) vira mensagem genérica', () async {
    servidor.rota('GET', '/x', (_) => http.Response('<html>Bad Gateway</html>', 502));

    await expectLater(
      client.get('/x'),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 502).having((e) => e.mensagem, 'mensagem', contains('502'))),
    );
  });

  test('401 com token chama onNaoAutorizado e lança ApiException', () async {
    var chamou = 0;
    client.onNaoAutorizado = () => chamou++;
    client.token = 'vencido';
    servidor.rota('GET', '/catalogo', (_) => problema(401, 'nao_autorizado', 'x'));

    await expectLater(client.get('/catalogo'), throwsA(isA<ApiException>().having((e) => e.naoAutorizado, '401', isTrue)));
    expect(chamou, 1);
  });

  test('401 no login (sem token) NÃO derruba a sessão: é só senha errada', () async {
    var chamou = 0;
    client.onNaoAutorizado = () => chamou++;
    servidor.rota('POST', '/auth/login', (_) => problema(401, 'credenciais_invalidas', 'Login ou senha incorretos.'));

    await expectLater(
      client.post('/auth/login', corpo: {}, autenticado: false),
      throwsA(isA<ApiException>().having((e) => e.codigo, 'codigo', 'credenciais_invalidas')),
    );
    expect(chamou, 0);
  });

  test('sem rede lança SemConexaoException', () async {
    servidor.offline = true;

    await expectLater(client.get('/catalogo'), throwsA(isA<SemConexaoException>()));
  });

  test('timeout lança SemConexaoException', () async {
    final lento = ApiClient(
      baseUrl: 'http://teste.local',
      timeout: const Duration(milliseconds: 20),
      client: MockClient((_) => Completer<http.Response>().future),
    );

    await expectLater(lento.get('/catalogo'), throwsA(isA<SemConexaoException>()));
  });
}
