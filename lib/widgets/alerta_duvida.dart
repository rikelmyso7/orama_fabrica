import 'package:flutter/material.dart';

/// Sinal de alerta ao lado de um dado importado com ressalva (valor lido de uma planilha com texto
/// ambíguo, contagem sem valor, saldo negativo). Tocar nele explica o que conferir.
class AlertaDuvida extends StatelessWidget {
  const AlertaDuvida({
    super.key,
    required this.titulo,
    required this.motivos,
    this.textoOriginal,
  });

  final String titulo;
  final List<String> motivos;

  /// Como o dado estava escrito na origem, quando se sabe.
  final String? textoOriginal;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Conferir este dado',
      visualDensity: VisualDensity.compact,
      icon: Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800),
      onPressed: () => showDialog<void>(
        context: context,
        builder: (_) => _ExplicacaoDaDuvida(
            titulo: titulo, motivos: motivos, textoOriginal: textoOriginal),
      ),
    );
  }
}

class _ExplicacaoDaDuvida extends StatelessWidget {
  const _ExplicacaoDaDuvida(
      {required this.titulo,
      required this.motivos,
      required this.textoOriginal});

  final String titulo;
  final List<String> motivos;
  final String? textoOriginal;

  @override
  Widget build(BuildContext context) {
    final estilo = Theme.of(context).textTheme;
    final original = textoOriginal?.trim();
    return AlertDialog(
      icon: Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800),
      title: Text(titulo),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Este dado precisa de conferência:', style: estilo.titleSmall),
            const SizedBox(height: 8),
            for (final motivo in motivos)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $motivo'),
              ),
            if (original != null && original.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Como estava na planilha:', style: estilo.titleSmall),
              const SizedBox(height: 4),
              Text(original),
            ],
            const SizedBox(height: 12),
            Text(
              'O alerta some quando o item for contado de novo.',
              style: estilo.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar')),
      ],
    );
  }
}
