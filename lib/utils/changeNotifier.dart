import 'package:flutter/material.dart';

class EstoqueController extends ChangeNotifier {
  final Map<String, TextEditingController> entradaControllers = {};
  final Map<String, TextEditingController> qtdAnteriorControllers = {};
  final Map<String, String> tipoSelecionado = {};

  void initializeFields(Map<String, dynamic> insumos, Map<String, dynamic>? reportData) {
    if (reportData != null) {
      // Popula com dados existentes
      _populateControllersFromReport(insumos, reportData);
    } else {
      // Inicializa campos vazios
      _initializeEmptyFields(insumos);
    }
  }

  void _populateControllersFromReport(Map<String, dynamic> insumos, Map<String, dynamic> reportData) {
    reportData['Categorias']?.forEach((category) {
      final itens = category['Itens'];
      for (final item in itens) {
        final key = _generateKey(category['Categoria'], item['Item']);
        entradaControllers[key] = TextEditingController(text: item['Entrada']?.toString() ?? '');
        qtdAnteriorControllers[key] = TextEditingController(text: item['Qtd_anterior']?.toString() ?? '');
        tipoSelecionado[key] = item['tipo'] ?? "Un";
      }
    });
  }

  void _initializeEmptyFields(Map<String, dynamic> insumos) {
    for (final category in insumos.keys) {
      for (final item in insumos[category]!) {
        final key = _generateKey(category, item['nome']);
        entradaControllers[key] = TextEditingController();
        qtdAnteriorControllers[key] = TextEditingController(text: item['Qtd_anterior']?.toString() ?? '');
        tipoSelecionado[key] = "Un";
      }
    }
  }

  String _generateKey(String category, String itemName) {
    return (category == 'BALDES' || category == 'POTES' || category == 'CUBAS') 
        ? '${category}_$itemName' 
        : itemName;
  }

  @override
  void dispose() {
    for (var controller in entradaControllers.values) {
      controller.dispose();
    }
    for (var controller in qtdAnteriorControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}
