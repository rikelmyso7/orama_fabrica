// Teste de contrato: o app contra a orama_api de verdade (Postgres + Spring Boot).
//
// Só roda quando recebe o endereço de uma API de TESTE (nunca aponte para produção):
//   flutter test test/integracao/api_real_test.dart \
//     --dart-define=API_REAL_URL=http://127.0.0.1:8080 \
//     --dart-define=API_REAL_ADMIN_LOGIN=admin \
//     --dart-define=API_REAL_ADMIN_SENHA=<senha do administrador inicial>
//
// Cria um usuário novo a cada execução e lança entradas de verdade nessa API.
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:orama_fabrica2/api/api_client.dart';
import 'package:orama_fabrica2/api/models.dart';
import 'package:orama_fabrica2/api/orama_api.dart';
import 'package:orama_fabrica2/auth/auth_store.dart';
import 'package:orama_fabrica2/data/entrada_pendente.dart';
import 'package:orama_fabrica2/data/fila_entradas.dart';
import 'package:orama_fabrica2/storage/storage.dart';
import 'package:uuid/uuid.dart';

const _url = String.fromEnvironment('API_REAL_URL');
const _adminLogin = String.fromEnvironment('API_REAL_ADMIN_LOGIN', defaultValue: 'admin');
const _adminSenha = String.fromEnvironment('API_REAL_ADMIN_SENHA');

void main() {
  final pular = _url.isEmpty ? 'passe --dart-define=API_REAL_URL=<api de teste> para rodar' : null;

  group('contrato com a orama_api real', skip: pular, () {
    const uuid = Uuid();
    late String loginFabrica;
    late String senhaFabrica;
    late String senhaAutorizacao;

    late ApiClient client;
    late OramaApi api;
    late AuthStore auth;
    late FilaEntradas fila;
    late Catalogo catalogo;

    setUpAll(() async {
      final sufixo = Random.secure().nextInt(1 << 32).toRadixString(16);
      loginFabrica = 'fabrica-$sufixo';
      senhaFabrica = 'senha-$sufixo-${uuid.v4().substring(0, 8)}';
      senhaAutorizacao = 'autoriza-$sufixo-${uuid.v4().substring(0, 8)}';

      // Preparação, como o administrador faria pelo orama_admin: cria o usuário da fábrica e define a
      // senha de administrador usada nos estornos.
      final adminClient = ApiClient(baseUrl: _url);
      final adminLogin = await OramaApi(adminClient).login(_adminLogin, _adminSenha);
      adminClient.token = adminLogin.token;
      await adminClient.post('/usuarios', corpo: {
        'nome': 'Teste de contrato',
        'login': loginFabrica,
        'senha': senhaFabrica,
        'papel': 'fabrica',
      });
      final resposta = await http.put(
        Uri.parse('$_url/usuarios/${adminLogin.usuario.id}/senha-autorizacao'),
        headers: {'Authorization': 'Bearer ${adminLogin.token}', 'Content-Type': 'application/json'},
        body: jsonEncode({'senha': senhaAutorizacao}),
      );
      expect(resposta.statusCode, 204, reason: 'não foi possível definir a senha de autorização');

      // O app, do jeito que o aparelho monta: cliente, API, sessão e fila.
      client = ApiClient(baseUrl: _url);
      api = OramaApi(client);
      auth = AuthStore(api, client, MemorySecureStore());
      fila = FilaEntradas(api, MemoryKeyValueStore());
    });

    ItemCatalogo itemDe(String categoria, String nome) {
      final cat = catalogo.categorias.firstWhere((c) => c.nome == categoria);
      return catalogo.itens.firstWhere((i) => i.categoriaId == cat.id && i.nome.startsWith(nome));
    }

    EntradaPendente linha(String id, ItemCatalogo item, String quantidade, String unidade,
            {int? unidades, String? lote, String origem = 'producao'}) =>
        EntradaPendente(
          id: id,
          usuarioId: auth.usuario!.id,
          itemId: item.id,
          itemNome: item.nome,
          quantidade: quantidade,
          unidade: unidade,
          unidades: unidades,
          origem: origem,
          lote: lote,
          ocorridoEm: DateTime.now(),
        );

    test('senha errada: 401 com código estável, e o login certo guarda a sessão', () async {
      await expectLater(
        api.login(loginFabrica, 'senha-errada-123'),
        throwsA(isA<ApiException>()
            .having((e) => e.status, 'status', 401)
            .having((e) => e.codigo, 'codigo', 'credenciais_invalidas')
            .having((e) => e.mensagem, 'mensagem', 'Login ou senha incorretos.')),
      );

      await auth.entrar(loginFabrica, senhaFabrica);

      expect(auth.logado, isTrue);
      expect(auth.usuario!.papel, 'fabrica');
      expect(auth.podeLancar, isTrue);
    });

    test('o catálogo real chega com todos os campos que o app usa', () async {
      catalogo = await api.catalogo();

      expect(catalogo.itens.length, greaterThanOrEqualTo(273));
      expect(catalogo.locais.map((l) => l.nome), containsAll(['Câmara frigorífica', 'Geladeira', 'Oficina']));
      final balde = itemDe('Baldes', 'COCADA');
      expect(balde.controlaRecipiente, isTrue);
      expect(balde.unidadeBase, 'g');
      expect(balde.unidadesPermitidas, ['g', 'kg']);
      expect(catalogo.local(balde.localPadraoId)!.nome, 'Câmara frigorífica');
      final descartavel = itemDe('Descartáveis', 'AÇÚCAR SACHE');
      expect(catalogo.local(descartavel.localPadraoId)!.nome, 'Oficina');
      expect(descartavel.origemSugerida, 'compra');
    });

    test('entrada de recipientes e de item comum pela fila, com reenvio sem duplicar', () async {
      final balde = itemDe('Baldes', 'COCADA');
      final cookie = itemDe('Cookies', 'BROWNIE');
      final ids = [uuid.v4(), uuid.v4(), uuid.v4()];
      await fila.adicionar([
        linha(ids[0], balde, '4100', 'g', unidades: 1, lote: 'LC1'),
        linha(ids[1], balde, '3.85', 'kg', unidades: 1, lote: 'LC1'),
        linha(ids[2], cookie, '12', 'un'),
      ]);

      final r = await fila.enviar(auth.usuario!.id);

      expect((r.enviadas, r.recusadas, r.indisponivel), (3, 0, false));
      expect(fila.doUsuario(auth.usuario!.id), isEmpty);

      // reenviar o mesmo lançamento (por exemplo, a resposta se perdeu): a API reconhece o id
      final repetido = await api.enviarEntradas([linha(ids[0], balde, '4100', 'g', unidades: 1, lote: 'LC1').paraApi()]);
      expect(repetido.single.status, 'ja_registrado');
      expect(repetido.single.etiqueta, startsWith('R'));
    });

    test('a API recusa balde sem lote e o app lê o motivo em português', () async {
      final balde = itemDe('Baldes', 'COCADA');
      final id = uuid.v4();

      final r = await api.enviarEntradas([linha(id, balde, '4100', 'g', unidades: 1).paraApi()]);

      expect(r.single.status, 'recusado');
      expect(r.single.registrada, isFalse);
      expect(r.single.erro, contains('lote'));
    });

    test('histórico, saldo e recipientes do dia refletem o que foi lançado', () async {
      final balde = itemDe('Baldes', 'COCADA');
      final hoje = DateTime.now();

      final movimentos = await api.movimentos(de: hoje, ate: hoje, itemId: balde.id);
      final doTeste = movimentos.where((m) => m.lote == 'LC1' && m.tipo == 'entrada').toList();
      expect(doTeste.length, greaterThanOrEqualTo(2));
      expect(doTeste.first.item, 'COCADA');
      expect(doTeste.first.local, 'Câmara frigorífica');
      expect(doTeste.first.etiqueta, startsWith('R'));
      expect(doTeste.first.usuario, 'Teste de contrato');
      expect(doTeste.first.estornado, isFalse);

      final saldo = (await api.saldo()).where((s) => s.itemId == balde.id).single;
      expect(saldo.local, 'Câmara frigorífica');
      expect(saldo.saldoUnidades, greaterThanOrEqualTo(2));
      expect(saldo.saldoBase, greaterThanOrEqualTo(7950));

      final recipientes = (await api.recipientes(balde.id)).where((r) => r.lote == 'LC1').toList();
      expect(recipientes.map((r) => r.pesoBase), containsAll([4100, 3850]));
      expect(recipientes.first.etiqueta, startsWith('R'));
    });

    test('estorno: senha errada é recusada, a certa funciona e o saldo volta', () async {
      final cookie = itemDe('Cookies', 'BROWNIE');
      final id = uuid.v4();
      await api.enviarEntradas([linha(id, cookie, '5', 'un').paraApi()]);
      Future<double> saldoDoCookie() async =>
          (await api.saldo()).where((s) => s.itemId == cookie.id).map((s) => s.saldoBase).fold<double>(0, (a, b) => a + b);
      final antes = await saldoDoCookie();

      await expectLater(
        api.estornar(movimentoId: id, novoId: uuid.v4(), motivo: 'teste', senha: 'senha-errada-123'),
        throwsA(isA<ApiException>().having((e) => e.codigo, 'codigo', 'senha_invalida')),
      );
      expect(await saldoDoCookie(), antes);

      await api.estornar(movimentoId: id, novoId: uuid.v4(), motivo: 'lançado errado', senha: senhaAutorizacao);

      expect(await saldoDoCookie(), antes - 5);
      final hoje = DateTime.now();
      final historico = await api.movimentos(de: hoje, ate: hoje, itemId: cookie.id);
      final original = historico.firstWhere((m) => m.id == id);
      expect(original.estornado, isTrue);
      expect(original.podeEstornar, isFalse);
      final estorno = historico.firstWhere((m) => m.estornaId == id);
      expect(estorno.tipo, 'saida');
      expect(estorno.motivo, 'lançado errado');
      expect(estorno.autorizadoPor, isNotNull);
    });

    test('token inválido: a API devolve 401 e o app derruba a sessão', () async {
      final outro = ApiClient(baseUrl: _url)..token = 'isto.nao.e-um-token';
      var caiu = false;
      outro.onNaoAutorizado = () => caiu = true;

      await expectLater(OramaApi(outro).catalogo(), throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)));
      expect(caiu, isTrue);
    });

    test('sem permissão: quem não é da fábrica recebe 403 com o código certo', () async {
      // o administrador cria um usuário de loja; o app deve mostrar a mensagem da API
      final sufixo = uuid.v4().substring(0, 8);
      final adminClient = ApiClient(baseUrl: _url);
      final admin = await OramaApi(adminClient).login(_adminLogin, _adminSenha);
      adminClient.token = admin.token;
      await adminClient.post('/usuarios', corpo: {
        'nome': 'Loja de teste', 'login': 'loja-$sufixo', 'senha': 'senha-loja-$sufixo', 'papel': 'loja',
      });
      final lojaClient = ApiClient(baseUrl: _url);
      final lojaApi = OramaApi(lojaClient);
      lojaClient.token = (await lojaApi.login('loja-$sufixo', 'senha-loja-$sufixo')).token;

      await expectLater(
        lojaApi.movimentos(),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 403).having((e) => e.codigo, 'codigo', 'acesso_negado')),
      );
    });
  });
}
