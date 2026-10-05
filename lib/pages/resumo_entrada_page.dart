import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../auth/auth_store.dart';
import '../data/entrada_pendente.dart';
import '../data/fila_entradas.dart';
import '../data/rascunho_entrada.dart';

/// Texto do aviso depois de salvar: o que foi registrado, o que espera conexão e o que foi recusado.
String mensagemDoEnvio(ResultadoSync r, int total) {
  if (r.ocupado) {
    return '$total ${total == 1 ? 'linha salva' : 'linhas salvas'}. O envio já está em andamento.';
  }
  final partes = <String>[];
  if (r.enviadas > 0) {
    partes.add('${r.enviadas} ${r.enviadas == 1 ? 'registrada' : 'registradas'}');
  }
  final esperando = total - r.enviadas - r.recusadas;
  if (esperando > 0) {
    partes.add('$esperando ${r.indisponivel ? 'aguardando conexão' : 'aguardando envio'}');
  }
  if (r.recusadas > 0) {
    partes.add('${r.recusadas} ${r.recusadas == 1 ? 'recusada' : 'recusadas'}: veja em Hoje');
  }
  return partes.isEmpty ? 'Entrada salva.' : partes.join(' · ');
}

/// Revisão antes de salvar. Ao salvar, as linhas entram na fila do aparelho e são enviadas na hora;
/// sem internet, ficam guardadas e seguem sozinhas quando a conexão voltar.
class ResumoEntradaPage extends StatefulWidget {
  const ResumoEntradaPage({super.key, required this.rascunho});

  final RascunhoEntrada rascunho;

  @override
  State<ResumoEntradaPage> createState() => _ResumoEntradaPageState();
}

class _ResumoEntradaPageState extends State<ResumoEntradaPage> {
  bool _salvando = false;

  Future<void> _salvar() async {
    final usuario = context.read<AuthStore>().usuario;
    if (usuario == null) return;
    final fila = context.read<FilaEntradas>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _salvando = true);

    final linhas = widget.rascunho.concluir();
    await fila.adicionar(linhas);
    final resultado = await fila.enviar(usuario.id);

    navigator.popUntil((rota) => rota.isFirst);
    messenger.showSnackBar(SnackBar(content: Text(mensagemDoEnvio(resultado, linhas.length))));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.rascunho,
      builder: (context, _) {
        final linhas = widget.rascunho.linhas;
        final porItem = <String, List<EntradaPendente>>{};
        for (final l in linhas) {
          porItem.putIfAbsent(l.itemId, () => []).add(l);
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Revisar entrada')),
          body: linhas.isEmpty
              ? const Center(child: Text('Nenhuma linha na entrada.'))
              : ListView(
                  children: [
                    for (final grupo in porItem.values) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                        child: Text(grupo.first.itemNome, style: Theme.of(context).textTheme.titleSmall),
                      ),
                      for (final l in grupo)
                        ListTile(
                          dense: true,
                          title: Text(l.descricao),
                          subtitle: Text([
                            _origem(l.origem),
                            if (l.varianteRotulo != null) l.varianteRotulo!,
                            if (l.lote != null && l.lote!.isNotEmpty) 'Lote ${l.lote}',
                            if (l.validade != null) 'validade ${DateFormat('dd/MM/yyyy').format(l.validade!)}',
                            if (l.localNome != null) l.localNome!,
                          ].join(' · ')),
                          trailing: IconButton(
                            tooltip: 'Remover',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: _salvando ? null : () => widget.rascunho.remover(l.id),
                          ),
                        ),
                    ],
                  ],
                ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton(
                onPressed: (linhas.isEmpty || _salvando) ? null : _salvar,
                child: _salvando
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text('Salvar entrada (${linhas.length})'),
              ),
            ),
          ),
        );
      },
    );
  }

  static String _origem(String origem) => switch (origem) {
        'producao' => 'Produção',
        'compra' => 'Compra',
        'devolucao' => 'Devolução',
        _ => origem,
      };
}
