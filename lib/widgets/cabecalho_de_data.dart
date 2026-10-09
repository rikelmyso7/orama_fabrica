import 'package:flutter/material.dart';

import '../app.dart';

/// Seletor de data no padrão do Orama Admin: setas dos dois lados e a data em verde, em negrito,
/// que abre o calendário ao tocar.
class CabecalhoDeData extends StatelessWidget {
  const CabecalhoDeData({
    super.key,
    required this.texto,
    required this.aoAnterior,
    required this.aoProximo,
    required this.aoEscolher,
    this.dicaAnterior = 'Dia anterior',
    this.dicaProximo = 'Dia seguinte',
  });

  final String texto;
  final VoidCallback aoAnterior;

  /// Nulo quando não há o que avançar (já está no dia de hoje).
  final VoidCallback? aoProximo;
  final VoidCallback aoEscolher;
  final String dicaAnterior;
  final String dicaProximo;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
            tooltip: dicaAnterior,
            icon: const Icon(Icons.arrow_back),
            onPressed: aoAnterior),
        Flexible(
          child: TextButton(
            onPressed: aoEscolher,
            style: TextButton.styleFrom(foregroundColor: corPrincipal),
            child: Text(
              texto,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: corPrincipal),
            ),
          ),
        ),
        IconButton(
            tooltip: dicaProximo,
            icon: const Icon(Icons.arrow_forward),
            onPressed: aoProximo),
      ],
    );
  }
}

/// Calendário com a cor do app (o do admin também usa o verde).
Future<DateTime?> escolherDia(BuildContext context, DateTime inicial) =>
    showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('pt', 'BR'),
    );
