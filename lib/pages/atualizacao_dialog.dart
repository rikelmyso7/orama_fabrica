import 'package:flutter/material.dart';

import '../update/atualizacao.dart';

/// Procura uma versão nova e, se houver, oferece a atualização. É opcional: "Agora não" fecha o
/// aviso e o app segue normal. Qualquer falha na consulta é silenciosa.
Future<void> oferecerAtualizacao(
    BuildContext context, ServicoAtualizacao servico) async {
  final nova = await servico.verificar();
  if (nova == null || !context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => AtualizacaoDialog(servico: servico, atualizacao: nova),
  );
}

class AtualizacaoDialog extends StatefulWidget {
  const AtualizacaoDialog(
      {super.key, required this.servico, required this.atualizacao});

  final ServicoAtualizacao servico;
  final Atualizacao atualizacao;

  @override
  State<AtualizacaoDialog> createState() => _AtualizacaoDialogState();
}

class _AtualizacaoDialogState extends State<AtualizacaoDialog> {
  bool _baixando = false;
  double? _progresso;
  String? _erro;

  Future<void> _atualizar() async {
    setState(() {
      _baixando = true;
      _progresso = null;
      _erro = null;
    });
    try {
      await widget.servico.instalar(
        widget.atualizacao,
        aoProgredir: (p) {
          if (mounted) setState(() => _progresso = p);
        },
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _baixando = false;
          _erro =
              'Não foi possível baixar a atualização. Confira a conexão e tente de novo.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_baixando,
      child: AlertDialog(
        title: const Text('Nova versão disponível'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Versão ${widget.atualizacao.versao}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(widget.atualizacao.notasLegiveis),
              if (_baixando) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(value: _progresso),
              ],
              if (_erro != null) ...[
                const SizedBox(height: 12),
                Text(_erro!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: _baixando ? null : () => Navigator.pop(context),
              child: const Text('Agora não')),
          FilledButton(
              onPressed: _baixando ? null : _atualizar,
              child: const Text('Atualizar')),
        ],
      ),
    );
  }
}
