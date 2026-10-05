import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:orama_fabrica2/app.dart';
import 'package:orama_fabrica2/update/atualizacao.dart';
import 'package:orama_fabrica2/storage/storage.dart';

class Requisicao {
  final String metodo;
  final Uri uri;
  final Map<String, String> cabecalhos;
  final dynamic corpo;

  Requisicao(this.metodo, this.uri, this.cabecalhos, this.corpo);

  String get caminho => uri.path;
}

typedef Rota = FutureOr<http.Response> Function(Requisicao r);

http.Response json(Object? corpo, {int status = 200}) => http.Response.bytes(
      utf8.encode(jsonEncode(corpo)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// Erro no formato da API (ProblemDetail): codigo estável e detail em português.
http.Response problema(int status, String codigo, String detail, {Map<String, Object?> extras = const {}}) =>
    json({'status': status, 'detail': detail, 'codigo': codigo, ...extras}, status: status);

/// Servidor HTTP falso: o app conversa com ele como se fosse a orama_api, sem rede.
class ServidorFalso {
  final Map<String, Rota> _rotas = {};
  final List<Requisicao> requisicoes = [];

  /// Quando verdadeiro, toda chamada falha como se não houvesse internet.
  bool offline = false;

  late final http.Client client = MockClient((req) async {
    final corpo = req.body.isEmpty ? null : jsonDecode(req.body);
    final r = Requisicao(req.method, req.url, req.headers, corpo);
    requisicoes.add(r);
    if (offline) throw http.ClientException('sem rede', req.url);
    final rota = _rotas['${req.method} ${req.url.path}'];
    if (rota == null) return problema(404, 'nao_encontrado', 'Rota sem resposta no teste: ${req.method} ${req.url.path}');
    return rota(r);
  });

  void rota(String metodo, String caminho, Rota resposta) => _rotas['$metodo $caminho'] = resposta;

  void responder(String metodo, String caminho, Object? corpo, {int status = 200}) =>
      rota(metodo, caminho, (_) => json(corpo, status: status));

  List<Requisicao> chamadas(String metodo, String caminho) =>
      requisicoes.where((r) => r.metodo == metodo && r.caminho == caminho).toList();
}

const usuarioFabricaJson = {'id': 'u-func', 'login': 'func1', 'nome': 'Funcionária', 'papel': 'fabrica'};

Map<String, Object?> loginJson({Map<String, Object?> usuario = usuarioFabricaJson, String token = 'token-abc'}) => {
      'token': token,
      'tipo': 'Bearer',
      'expiraEm': DateTime.now().toUtc().add(const Duration(hours: 12)).toIso8601String(),
      'usuario': usuario,
    };

/// Catálogo pequeno com os três tipos de item que mudam o formulário.
Map<String, Object?> catalogoJson() => {
      'locais': [
        {'id': 'loc-camara', 'nome': 'Câmara frigorífica', 'tipo': 'fabrica', 'temperatura': 'congelado'},
        {'id': 'loc-oficina', 'nome': 'Oficina', 'tipo': 'oficina', 'temperatura': 'seco'},
      ],
      'categorias': [
        {'id': 'cat-baldes', 'nome': 'Baldes'},
        {'id': 'cat-cookies', 'nome': 'Cookies'},
        {'id': 'cat-toppings', 'nome': 'Toppings'},
      ],
      'itens': [
        {
          'id': 'it-balde', 'nome': 'COCADA', 'categoriaId': 'cat-baldes', 'unidadeBase': 'g',
          'nivel': 'producao', 'temperatura': 'congelado', 'controlaValidade': true,
          'controlaRecipiente': true, 'localPadraoId': 'loc-camara', 'embalagens': [], 'variacoes': [],
        },
        {
          'id': 'it-cookie', 'nome': 'BROWNIE', 'categoriaId': 'cat-cookies', 'unidadeBase': 'un',
          'nivel': 'producao', 'temperatura': 'congelado', 'controlaValidade': false,
          'controlaRecipiente': false, 'localPadraoId': 'loc-camara', 'embalagens': [], 'variacoes': [],
        },
        {
          'id': 'it-castanha', 'nome': 'CASTANHA GLACEADA', 'categoriaId': 'cat-toppings', 'unidadeBase': 'g',
          'nivel': 'terceiros', 'temperatura': 'seco', 'controlaValidade': true,
          'controlaRecipiente': false, 'localPadraoId': 'loc-oficina',
          'embalagens': [{'embalagem': 'cx', 'qtdBase': 1000}], 'variacoes': [],
        },
      ],
    };

class Montagem {
  Montagem(this.servidor, this.deps, this.store, this.secure);

  final ServidorFalso servidor;
  final AppDependencias deps;
  final MemoryKeyValueStore store;
  final MemorySecureStore secure;
}

/// Monta as dependências reais do app apontando para o servidor falso.
Montagem montar({
  ServidorFalso? servidor,
  MemoryKeyValueStore? store,
  MemorySecureStore? secure,
  ServicoAtualizacao? atualizacao,
}) {
  final s = servidor ?? ServidorFalso();
  final kv = store ?? MemoryKeyValueStore();
  final sec = secure ?? MemorySecureStore();
  final deps = AppDependencias.criar(baseUrl: 'http://teste.local', store: kv, secure: sec, httpClient: s.client, atualizacao: atualizacao);
  return Montagem(s, deps, kv, sec);
}
