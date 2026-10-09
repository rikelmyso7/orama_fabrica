import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Erro devolvido pela API (ProblemDetail): [codigo] é estável, [mensagem] já vem em português.
class ApiException implements Exception {
  final int status;
  final String codigo;
  final String mensagem;
  final Map<String, dynamic> extras;

  const ApiException(this.status, this.codigo, this.mensagem,
      [this.extras = const {}]);

  bool get naoAutorizado => status == 401;

  @override
  String toString() => 'ApiException($status, $codigo): $mensagem';
}

/// Não foi possível falar com o servidor (sem internet, servidor fora do ar ou lento demais).
class SemConexaoException implements Exception {
  const SemConexaoException();

  String get mensagem => 'Sem conexão com o servidor.';

  @override
  String toString() => 'SemConexaoException';
}

/// Cliente HTTP da orama_api: envia o token, trata os erros e avisa quando a sessão expira.
class ApiClient {
  ApiClient({
    required String baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  })  : _base = Uri.parse(baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl),
        _client = client ?? http.Client();

  final Uri _base;
  final http.Client _client;
  final Duration timeout;

  String? token;

  /// Chamado quando uma requisição autenticada volta 401 (token inválido ou usuário desativado).
  void Function()? onNaoAutorizado;

  Uri _uri(String caminho, Map<String, String>? query) => _base.replace(
        path: '${_base.path}$caminho',
        queryParameters: (query == null || query.isEmpty) ? null : query,
      );

  Map<String, String> _cabecalhos(
          {required bool autenticado, bool json = false}) =>
      {
        'Accept': 'application/json',
        if (json) 'Content-Type': 'application/json; charset=utf-8',
        if (autenticado && token != null) 'Authorization': 'Bearer $token',
      };

  Future<dynamic> get(String caminho, {Map<String, String>? query}) => _enviar(
      () => _client.get(_uri(caminho, query),
          headers: _cabecalhos(autenticado: true)),
      autenticado: true);

  Future<dynamic> post(String caminho,
          {Object? corpo, bool autenticado = true}) =>
      _enviar(
        () => _client.post(
          _uri(caminho, null),
          headers: _cabecalhos(autenticado: autenticado, json: true),
          body: corpo == null ? null : jsonEncode(corpo),
        ),
        autenticado: autenticado,
      );

  Future<dynamic> put(String caminho, {Object? corpo}) => _enviar(
        () => _client.put(
          _uri(caminho, null),
          headers: _cabecalhos(autenticado: true, json: true),
          body: corpo == null ? null : jsonEncode(corpo),
        ),
        autenticado: true,
      );

  Future<dynamic> _enviar(Future<http.Response> Function() requisicao,
      {required bool autenticado}) async {
    final http.Response resposta;
    try {
      resposta = await requisicao().timeout(timeout);
    } on TimeoutException {
      throw const SemConexaoException();
    } on http.ClientException {
      throw const SemConexaoException();
    }

    final texto = utf8.decode(resposta.bodyBytes);
    if (resposta.statusCode >= 200 && resposta.statusCode < 300) {
      return texto.isEmpty ? null : jsonDecode(texto);
    }

    final erro = _lerErro(resposta.statusCode, texto);
    if (resposta.statusCode == 401 && autenticado) {
      onNaoAutorizado?.call();
      throw const ApiException(
          401, 'nao_autorizado', 'Sua sessão expirou. Entre de novo.');
    }
    throw erro;
  }

  ApiException _lerErro(int status, String texto) {
    try {
      final corpo = jsonDecode(texto);
      if (corpo is Map<String, dynamic>) {
        final extras = Map<String, dynamic>.from(corpo)
          ..remove('detail')
          ..remove('codigo');
        return ApiException(
          status,
          (corpo['codigo'] as String?) ?? 'erro',
          (corpo['detail'] as String?) ?? 'Erro $status.',
          extras,
        );
      }
    } on FormatException {
      // corpo que não é JSON (por exemplo, página de erro de um proxy)
    }
    return ApiException(status, 'erro', 'Erro $status. Tente novamente.');
  }

  void fechar() => _client.close();
}
