import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../api/orama_api.dart';
import '../storage/storage.dart';
import 'fila_entradas.dart';
import 'operacao_pendente.dart';

/// Operações de rastreabilidade V3 pendentes. Diferente da entrada antiga, uma operação é reenviada
/// como bloco único para preservar o vínculo entre consumo e produção.
class FilaOperacoes extends ChangeNotifier {
  FilaOperacoes(this._api, this._store) {
    _carregar();
  }

  static const chave = 'fila_operacoes_v1';

  final OramaApi _api;
  final KeyValueStore _store;
  final List<OperacaoPendente> _itens = [];
  bool _enviando = false;

  bool get enviando => _enviando;

  List<OperacaoPendente> doUsuario(String usuarioId) =>
      _itens.where((e) => e.usuarioId == usuarioId).toList(growable: false);

  int aguardando(String usuarioId) =>
      _itens.where((e) => e.usuarioId == usuarioId && e.erro == null).length;

  int recusadas(String usuarioId) =>
      _itens.where((e) => e.usuarioId == usuarioId && e.erro != null).length;

  Future<void> adicionar(OperacaoPendente nova) async {
    _itens.add(nova);
    await _salvar();
    notifyListeners();
  }

  Future<void> descartar(String id) async {
    _itens.removeWhere((e) => e.id == id);
    await _salvar();
    notifyListeners();
  }

  Future<void> tentarNovamente(String id) async {
    final i = _itens.indexWhere((e) => e.id == id);
    if (i < 0) return;
    _itens[i] = _itens[i].comErro(null);
    await _salvar();
    notifyListeners();
  }

  Future<ResultadoSync> enviar(String usuarioId) async {
    if (_enviando) return const ResultadoSync(ocupado: true);
    _enviando = true;
    notifyListeners();

    var enviadas = 0;
    var recusadas = 0;
    var indisponivel = false;
    try {
      final pendentes = _itens
          .where((e) => e.usuarioId == usuarioId && e.erro == null)
          .toList();
      for (final operacao in pendentes) {
        try {
          await _api.enviarOperacao(operacao.paraApi());
          _itens.removeWhere((x) => x.id == operacao.id);
          enviadas++;
          await _salvar();
        } on SemConexaoException {
          indisponivel = true;
          break;
        } on ApiException catch (e) {
          if (e.naoAutorizado || e.status >= 500) {
            indisponivel = e.status >= 500;
            break;
          }
          _trocar(operacao.comErro(e.mensagem));
          recusadas++;
          await _salvar();
        }
      }
    } finally {
      _enviando = false;
      notifyListeners();
    }
    return ResultadoSync(
        enviadas: enviadas, recusadas: recusadas, indisponivel: indisponivel);
  }

  void _carregar() {
    final texto = _store.ler(chave);
    if (texto == null) return;
    try {
      for (final e in jsonDecode(texto) as List) {
        _itens.add(OperacaoPendente.fromJson(e as Map<String, dynamic>));
      }
    } on Object {
      _itens.clear();
    }
  }

  Future<void> _salvar() =>
      _store.gravar(chave, jsonEncode(_itens.map((e) => e.toJson()).toList()));

  void _trocar(OperacaoPendente nova) {
    final i = _itens.indexWhere((e) => e.id == nova.id);
    if (i >= 0) _itens[i] = nova;
  }
}
