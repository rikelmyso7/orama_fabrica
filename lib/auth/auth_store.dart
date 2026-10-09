import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../api/orama_api.dart';
import '../storage/storage.dart';

enum EstadoAuth { carregando, deslogado, logado }

/// Sessão do usuário. O token fica no armazenamento seguro do aparelho e vale até expirar ou até a
/// API recusar (usuário desativado, por exemplo): nesse caso o app volta para a tela de login.
class AuthStore extends ChangeNotifier {
  AuthStore(this._api, this._client, this._secure, {DateTime Function()? agora})
      : _agora = agora ?? DateTime.now {
    _client.onNaoAutorizado = () => sair();
  }

  static const _chaveToken = 'token';
  static const _chaveUsuario = 'usuario';
  static const _chaveExpira = 'expira_em';

  final OramaApi _api;
  final ApiClient _client;
  final SecureStore _secure;
  final DateTime Function() _agora;

  EstadoAuth estado = EstadoAuth.carregando;
  UsuarioLogado? usuario;

  bool get logado => estado == EstadoAuth.logado;

  /// Quem lança entradas e estorna (administrador e fábrica).
  bool get podeLancar => usuario?.podeLancar ?? false;

  Future<void> restaurar() async {
    final token = await _secure.ler(_chaveToken);
    final usuarioJson = await _secure.ler(_chaveUsuario);
    final expira = DateTime.tryParse(await _secure.ler(_chaveExpira) ?? '');
    if (token != null &&
        usuarioJson != null &&
        expira != null &&
        expira.isAfter(_agora())) {
      try {
        usuario = UsuarioLogado.fromJson(
            jsonDecode(usuarioJson) as Map<String, dynamic>);
        _client.token = token;
        estado = EstadoAuth.logado;
        notifyListeners();
        return;
      } on FormatException {
        // dado corrompido: cai para o login
      }
    }
    await _limpar();
    estado = EstadoAuth.deslogado;
    notifyListeners();
  }

  /// Lança [ApiException] (senha errada, bloqueio) ou [SemConexaoException].
  Future<void> entrar(String login, String senha) async {
    final r = await _api.login(login, senha);
    await _secure.gravar(_chaveToken, r.token);
    await _secure.gravar(_chaveUsuario, jsonEncode(r.usuario.toJson()));
    await _secure.gravar(_chaveExpira, r.expiraEm.toUtc().toIso8601String());
    _client.token = r.token;
    usuario = r.usuario;
    estado = EstadoAuth.logado;
    notifyListeners();
  }

  Future<void> sair() async {
    if (estado == EstadoAuth.deslogado) return;
    await _limpar();
    estado = EstadoAuth.deslogado;
    notifyListeners();
  }

  Future<void> _limpar() async {
    _client.token = null;
    usuario = null;
    await _secure.remover(_chaveToken);
    await _secure.remover(_chaveUsuario);
    await _secure.remover(_chaveExpira);
  }
}
