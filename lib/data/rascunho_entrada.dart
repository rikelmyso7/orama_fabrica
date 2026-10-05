import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../api/models.dart';
import '../util/numero.dart';
import 'entrada_pendente.dart';

/// Um peso digitado para um recipiente (balde, cuba ou pote).
class PesoDigitado {
  final double valor;

  /// g ou kg.
  final String unidade;

  const PesoDigitado(this.valor, this.unidade);
}

/// As linhas da entrada que o funcionário está montando, antes de salvar. Cada linha já nasce com o
/// seu id, que é o que torna o reenvio seguro.
class RascunhoEntrada extends ChangeNotifier {
  RascunhoEntrada({required this.usuarioId, Uuid? uuid, DateTime Function()? agora})
      : _uuid = uuid ?? const Uuid(),
        _agora = agora ?? DateTime.now;

  final String usuarioId;
  final Uuid _uuid;
  final DateTime Function() _agora;
  final List<EntradaPendente> _linhas = [];

  List<EntradaPendente> get linhas => List.unmodifiable(_linhas);

  int get total => _linhas.length;

  int totalDoItem(String itemId) => _linhas.where((l) => l.itemId == itemId).length;

  /// Item comum: uma linha, com a quantidade e a unidade escolhidas.
  void adicionarComum({
    required ItemCatalogo item,
    required double quantidade,
    required String unidade,
    required String origem,
    Variacao? variacao,
    String? localNome,
    String? lote,
    DateTime? validade,
    String? documento,
    String? textoOriginal,
  }) {
    _linhas.add(EntradaPendente(
      id: _uuid.v4(),
      usuarioId: usuarioId,
      itemId: item.id,
      itemNome: item.nome,
      varianteId: variacao?.id,
      varianteRotulo: variacao?.rotulo,
      localNome: localNome,
      quantidade: Numero.paraApi(quantidade),
      unidade: unidade,
      origem: origem,
      lote: lote,
      validade: validade,
      documento: documento,
      textoOriginal: textoOriginal,
      ocorridoEm: _agora(),
    ));
    notifyListeners();
  }

  /// Balde, cuba ou pote: uma linha por recipiente, com o peso real de cada um e o mesmo lote e dia.
  void adicionarRecipientes({
    required ItemCatalogo item,
    required List<PesoDigitado> pesos,
    required String lote,
    required DateTime dia,
    required String origem,
    Variacao? variacao,
    String? localNome,
    DateTime? validade,
  }) {
    if (lote.trim().isEmpty) {
      throw ArgumentError('O lote é obrigatório para recipientes.');
    }
    final quando = _momentoDoDia(dia);
    for (final p in pesos) {
      _linhas.add(EntradaPendente(
        id: _uuid.v4(),
        usuarioId: usuarioId,
        itemId: item.id,
        itemNome: item.nome,
        varianteId: variacao?.id,
        varianteRotulo: variacao?.rotulo,
        localNome: localNome,
        quantidade: Numero.paraApi(p.valor),
        unidade: p.unidade,
        unidades: 1,
        origem: origem,
        lote: lote.trim(),
        validade: validade,
        textoOriginal: Numero.formatar(p.valor, p.unidade),
        ocorridoEm: quando,
      ));
    }
    notifyListeners();
  }

  void remover(String id) {
    _linhas.removeWhere((l) => l.id == id);
    notifyListeners();
  }

  /// Entrega as linhas para a fila e zera o rascunho.
  List<EntradaPendente> concluir() {
    final linhas = List<EntradaPendente>.from(_linhas);
    _linhas.clear();
    notifyListeners();
    return linhas;
  }

  /// Hoje vale a hora atual. Outro dia (lançamento atrasado) vale o meio-dia daquele dia.
  DateTime _momentoDoDia(DateTime dia) {
    final agora = _agora();
    if (dia.year == agora.year && dia.month == agora.month && dia.day == agora.day) return agora;
    return DateTime(dia.year, dia.month, dia.day, 12);
  }
}
