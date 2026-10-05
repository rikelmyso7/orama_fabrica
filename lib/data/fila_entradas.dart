import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../api/orama_api.dart';
import '../storage/storage.dart';
import 'entrada_pendente.dart';

class ResultadoSync {
  /// Linhas aceitas pela API (novas ou já registradas).
  final int enviadas;

  /// Linhas que a API recusou, com o motivo guardado na própria linha.
  final int recusadas;

  /// Sem internet ou servidor indisponível: as linhas continuam na fila.
  final bool indisponivel;

  /// Já havia um envio em andamento.
  final bool ocupado;

  const ResultadoSync({this.enviadas = 0, this.recusadas = 0, this.indisponivel = false, this.ocupado = false});
}

/// Entradas lançadas e ainda não confirmadas pela API. Ficam no aparelho até serem aceitas, então
/// um lançamento feito sem internet não se perde. O envio é seguro de repetir: cada linha tem o seu id.
class FilaEntradas extends ChangeNotifier {
  FilaEntradas(this._api, this._store) {
    _carregar();
  }

  static const chave = 'fila_entradas_v1';
  static const tamanhoLote = 100;

  final OramaApi _api;
  final KeyValueStore _store;
  final List<EntradaPendente> _itens = [];
  bool _enviando = false;

  bool get enviando => _enviando;

  List<EntradaPendente> doUsuario(String usuarioId) =>
      _itens.where((e) => e.usuarioId == usuarioId).toList(growable: false);

  /// Aguardando envio (sem erro).
  int aguardando(String usuarioId) => _itens.where((e) => e.usuarioId == usuarioId && e.erro == null).length;

  /// Recusadas pela API: precisam de uma decisão do usuário (descartar ou tentar de novo).
  int recusadas(String usuarioId) => _itens.where((e) => e.usuarioId == usuarioId && e.erro != null).length;

  void _carregar() {
    final texto = _store.ler(chave);
    if (texto == null) return;
    try {
      for (final e in jsonDecode(texto) as List) {
        _itens.add(EntradaPendente.fromJson(e as Map<String, dynamic>));
      }
    } on Object {
      // fila ilegível: não apaga o arquivo (pode ser recuperado), só não carrega
      _itens.clear();
    }
  }

  Future<void> _salvar() => _store.gravar(chave, jsonEncode(_itens.map((e) => e.toJson()).toList()));

  Future<void> adicionar(List<EntradaPendente> novas) async {
    _itens.addAll(novas);
    await _salvar();
    notifyListeners();
  }

  Future<void> descartar(String id) async {
    _itens.removeWhere((e) => e.id == id);
    await _salvar();
    notifyListeners();
  }

  /// Tira o erro de uma linha recusada, para ela entrar de novo no próximo envio.
  Future<void> tentarNovamente(String id) async {
    final i = _itens.indexWhere((e) => e.id == id);
    if (i < 0) return;
    _itens[i] = _itens[i].comErro(null);
    await _salvar();
    notifyListeners();
  }

  /// Envia as linhas do usuário que ainda não têm erro. Linhas aceitas saem da fila; recusadas ficam
  /// com o motivo; se não houver conexão, tudo fica para a próxima tentativa.
  Future<ResultadoSync> enviar(String usuarioId) async {
    if (_enviando) return const ResultadoSync(ocupado: true);
    _enviando = true;
    notifyListeners();

    var enviadas = 0;
    var recusadas = 0;
    var indisponivel = false;
    try {
      final pendentes = _itens.where((e) => e.usuarioId == usuarioId && e.erro == null).toList();
      for (var i = 0; i < pendentes.length; i += tamanhoLote) {
        final lote = pendentes.sublist(i, min(i + tamanhoLote, pendentes.length));
        final List<ResultadoEntrada> resultados;
        try {
          resultados = await _api.enviarEntradas(lote.map((e) => e.paraApi()).toList());
        } on SemConexaoException {
          indisponivel = true;
          break;
        } on ApiException catch (e) {
          if (e.naoAutorizado || e.status >= 500) {
            // sessão expirada ou servidor com problema: nada é perdido, tenta de novo depois
            indisponivel = e.status >= 500;
            break;
          }
          // a API entendeu e recusou o pedido inteiro (por exemplo, sem permissão): guarda o motivo
          for (final linha in lote) {
            _trocar(linha.comErro(e.mensagem));
          }
          recusadas += lote.length;
          await _salvar();
          continue;
        }

        final porId = {for (final r in resultados) r.id: r};
        for (final linha in lote) {
          final r = porId[linha.id];
          if (r == null) continue; // resposta incompleta: a linha continua na fila
          if (r.registrada) {
            _itens.removeWhere((x) => x.id == linha.id);
            enviadas++;
          } else {
            _trocar(linha.comErro(r.erro ?? 'Entrada recusada.'));
            recusadas++;
          }
        }
        await _salvar();
      }
    } finally {
      _enviando = false;
      notifyListeners();
    }
    return ResultadoSync(enviadas: enviadas, recusadas: recusadas, indisponivel: indisponivel);
  }

  void _trocar(EntradaPendente nova) {
    final i = _itens.indexWhere((e) => e.id == nova.id);
    if (i >= 0) _itens[i] = nova;
  }
}
