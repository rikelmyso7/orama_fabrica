import 'package:flutter/material.dart';

class EstornoDados {
  final String motivo;
  final String senha;

  const EstornoDados(this.motivo, this.senha);
}

/// Pede o motivo e a senha de administrador para estornar um lançamento. A senha não é guardada:
/// vai direto para o servidor, que a confere.
class EstornoDialog extends StatefulWidget {
  const EstornoDialog({super.key, required this.descricao});

  final String descricao;

  @override
  State<EstornoDialog> createState() => _EstornoDialogState();
}

class _EstornoDialogState extends State<EstornoDialog> {
  final _motivo = TextEditingController();
  final _senha = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _ocultar = true;

  @override
  void dispose() {
    _motivo.dispose();
    _senha.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Estornar lançamento'),
      content: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.descricao),
              const SizedBox(height: 4),
              const Text('O lançamento não é apagado: um estorno é registrado no lugar.',
                  style: TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _motivo,
                maxLength: 300,
                decoration: const InputDecoration(labelText: 'Motivo'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o motivo' : null,
              ),
              TextFormField(
                controller: _senha,
                obscureText: _ocultar,
                decoration: InputDecoration(
                  labelText: 'Senha de administrador',
                  suffixIcon: IconButton(
                    tooltip: _ocultar ? 'Mostrar senha' : 'Esconder senha',
                    icon: Icon(_ocultar ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _ocultar = !_ocultar),
                  ),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Informe a senha' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            if (_form.currentState!.validate()) {
              Navigator.pop(context, EstornoDados(_motivo.text.trim(), _senha.text));
            }
          },
          child: const Text('Estornar'),
        ),
      ],
    );
  }
}
