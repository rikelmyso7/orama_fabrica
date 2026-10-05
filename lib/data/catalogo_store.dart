import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../api/orama_api.dart';
import '../storage/storage.dart';
import '../util/texto.dart';

/// Catálogo de itens, com cache no aparelho: a tela de entrada abre mesmo sem internet.
class CatalogoStore extends ChangeNotifier {
  CatalogoStore(this._api, this._store, {DateTime Function()? agora}) : _agora = agora ?? DateTime.now {
    _carregarCache();
  }

  static const chave = 'catalogo_v1';
  static const validadeDoCache = Duration(hours: 1);

  final OramaApi _api;
  final KeyValueStore _store;
  final DateTime Function() _agora;

  Catalogo? catalogo;
  DateTime? atualizadoEm;
  bool carregando = false;

  /// Aviso para mostrar na tela (por exemplo, "usando o catálogo salvo"). Nulo quando está tudo certo.
  String? aviso;

  bool get precisaAtualizar =>
      catalogo == null || atualizadoEm == null || _agora().difference(atualizadoEm!) > validadeDoCache;

  void _carregarCache() {
    final texto = _store.ler(chave);
    if (texto == null) return;
    try {
      final j = jsonDecode(texto) as Map<String, dynamic>;
      catalogo = Catalogo.fromJson(j['catalogo'] as Map<String, dynamic>);
      atualizadoEm = DateTime.tryParse(j['atualizadoEm'] as String? ?? '');
    } on Object {
      // cache ilegível: ignora e busca de novo
      catalogo = null;
    }
  }

  Future<void> atualizar() async {
    if (carregando) return;
    carregando = true;
    notifyListeners();
    try {
      final novo = await _api.catalogo();
      catalogo = novo;
      atualizadoEm = _agora();
      aviso = null;
      await _store.gravar(
        chave,
        jsonEncode({'atualizadoEm': atualizadoEm!.toUtc().toIso8601String(), 'catalogo': novo.toJson()}),
      );
    } on SemConexaoException {
      aviso = catalogo == null
          ? 'Sem conexão e sem catálogo salvo. Conecte-se para carregar os itens.'
          : 'Sem conexão. Usando o catálogo salvo.';
    } on ApiException catch (e) {
      aviso = e.mensagem;
    } finally {
      carregando = false;
      notifyListeners();
    }
  }

  /// Itens da categoria (ou de todas, se nula) que casam com a busca, em ordem alfabética.
  List<ItemCatalogo> itens({String? categoriaId, String busca = ''}) {
    final todos = catalogo?.itens ?? const <ItemCatalogo>[];
    final filtrados = todos.where((i) {
      if (categoriaId != null && i.categoriaId != categoriaId) return false;
      return busca.trim().isEmpty || Texto.contem(i.nome, busca);
    }).toList()
      ..sort((a, b) => Texto.normalizar(a.nome).compareTo(Texto.normalizar(b.nome)));
    return filtrados;
  }
}
