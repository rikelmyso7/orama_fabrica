import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../storage/storage.dart';

class LinhaFormula {
  final String itemId;
  final String itemNome;
  final String quantidade;
  final String unidade;

  const LinhaFormula({
    required this.itemId,
    required this.itemNome,
    required this.quantidade,
    required this.unidade,
  });

  Map<String, dynamic> toJson() => {
        'itemId': itemId,
        'itemNome': itemNome,
        'quantidade': quantidade,
        'unidade': unidade,
      };

  factory LinhaFormula.fromJson(Map<String, dynamic> j) => LinhaFormula(
        itemId: j['itemId'] as String,
        itemNome: j['itemNome'] as String,
        quantidade: j['quantidade'] as String,
        unidade: j['unidade'] as String,
      );
}

class FormulaItem {
  final String itemProduzidoId;
  final String itemProduzidoNome;
  final List<LinhaFormula> linhas;

  const FormulaItem({
    required this.itemProduzidoId,
    required this.itemProduzidoNome,
    required this.linhas,
  });

  Map<String, dynamic> toJson() => {
        'itemProduzidoId': itemProduzidoId,
        'itemProduzidoNome': itemProduzidoNome,
        'linhas': linhas.map((e) => e.toJson()).toList(),
      };

  factory FormulaItem.fromJson(Map<String, dynamic> j) => FormulaItem(
        itemProduzidoId: j['itemProduzidoId'] as String,
        itemProduzidoNome: j['itemProduzidoNome'] as String,
        linhas: ((j['linhas'] as List?) ?? const [])
            .map((e) => LinhaFormula.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class FormulasStore extends ChangeNotifier {
  FormulasStore(this._store) {
    _carregar();
  }

  static const chave = 'formulas_v1';

  final KeyValueStore _store;
  final List<FormulaItem> _formulas = [];

  List<FormulaItem> get formulas => List.unmodifiable(_formulas);

  FormulaItem? doItem(String itemId) {
    for (final f in _formulas) {
      if (f.itemProduzidoId == itemId) return f;
    }
    return null;
  }

  bool temFormula(String itemId) => doItem(itemId) != null;

  Future<void> salvar(FormulaItem formula) async {
    final i = _formulas
        .indexWhere((e) => e.itemProduzidoId == formula.itemProduzidoId);
    if (i >= 0) {
      _formulas[i] = formula;
    } else {
      _formulas.add(formula);
    }
    _formulas
        .sort((a, b) => a.itemProduzidoNome.compareTo(b.itemProduzidoNome));
    await _salvar();
    notifyListeners();
  }

  Future<void> remover(String itemProduzidoId) async {
    _formulas.removeWhere((e) => e.itemProduzidoId == itemProduzidoId);
    await _salvar();
    notifyListeners();
  }

  void _carregar() {
    final texto = _store.ler(chave);
    if (texto == null) return;
    try {
      _formulas
        ..clear()
        ..addAll((jsonDecode(texto) as List)
            .map((e) => FormulaItem.fromJson(e as Map<String, dynamic>)));
    } on Object {
      _formulas.clear();
    }
  }

  Future<void> _salvar() => _store.gravar(
      chave, jsonEncode(_formulas.map((e) => e.toJson()).toList()));
}
