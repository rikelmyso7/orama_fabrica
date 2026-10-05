import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../auth/auth_store.dart';
import '../data/catalogo_store.dart';
import '../data/rascunho_entrada.dart';
import 'item_entrada_sheet.dart';
import 'resumo_entrada_page.dart';

/// Escolha dos itens que entraram. Tocar em um item abre o formulário dele; as linhas ficam em um
/// rascunho até o funcionário revisar e salvar.
class NovaEntradaPage extends StatefulWidget {
  const NovaEntradaPage({super.key});

  @override
  State<NovaEntradaPage> createState() => _NovaEntradaPageState();
}

class _NovaEntradaPageState extends State<NovaEntradaPage> {
  late final RascunhoEntrada _rascunho;
  final _busca = TextEditingController();
  String? _categoriaId;

  @override
  void initState() {
    super.initState();
    _rascunho = RascunhoEntrada(usuarioId: context.read<AuthStore>().usuario!.id);
    final catalogo = context.read<CatalogoStore>();
    if (catalogo.catalogo == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => catalogo.atualizar());
    }
  }

  @override
  void dispose() {
    _rascunho.dispose();
    _busca.dispose();
    super.dispose();
  }

  Future<bool> _confirmarSaida() async {
    final sair = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Descartar entrada?'),
        content: Text('Você tem ${_rascunho.total} ${_rascunho.total == 1 ? 'linha' : 'linhas'} que ainda não foram salvas.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Continuar editando')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Descartar')),
        ],
      ),
    );
    return sair ?? false;
  }

  void _revisar() {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ResumoEntradaPage(rascunho: _rascunho)));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CatalogoStore>();
    final catalogo = store.catalogo;

    return ListenableBuilder(
      listenable: _rascunho,
      builder: (context, _) => PopScope(
        canPop: _rascunho.total == 0,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          final navigator = Navigator.of(context);
          if (await _confirmarSaida()) navigator.pop();
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Nova entrada'),
            // maybePop respeita o aviso de "descartar entrada?" (PopScope)
            leading: BackButton(onPressed: () => Navigator.of(context).maybePop()),
          ),
          body: catalogo == null ? _SemCatalogo(store: store) : _Corpo(
            catalogo: catalogo,
            store: store,
            busca: _busca,
            categoriaId: _categoriaId,
            rascunho: _rascunho,
            aoMudarCategoria: (id) => setState(() => _categoriaId = id),
            aoBuscar: () => setState(() {}),
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                onPressed: _rascunho.total == 0 ? null : _revisar,
                icon: const Icon(Icons.fact_check_outlined),
                label: Text('Revisar entrada (${_rascunho.total})'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SemCatalogo extends StatelessWidget {
  const _SemCatalogo({required this.store});

  final CatalogoStore store;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: store.carregando
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(store.aviso ?? 'O catálogo de itens ainda não foi carregado.', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: store.atualizar, child: const Text('Tentar de novo')),
                ],
              ),
      ),
    );
  }
}

class _Corpo extends StatelessWidget {
  const _Corpo({
    required this.catalogo,
    required this.store,
    required this.busca,
    required this.categoriaId,
    required this.rascunho,
    required this.aoMudarCategoria,
    required this.aoBuscar,
  });

  final Catalogo catalogo;
  final CatalogoStore store;
  final TextEditingController busca;
  final String? categoriaId;
  final RascunhoEntrada rascunho;
  final void Function(String?) aoMudarCategoria;
  final VoidCallback aoBuscar;

  @override
  Widget build(BuildContext context) {
    final itens = store.itens(categoriaId: categoriaId, busca: busca.text);
    return Column(
      children: [
        if (store.aviso != null)
          Container(
            width: double.infinity,
            color: Colors.orange.shade50,
            padding: const EdgeInsets.all(8),
            child: Text(store.aviso!, style: TextStyle(color: Colors.orange.shade900)),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            controller: busca,
            onChanged: (_) => aoBuscar(),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar item',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: ChoiceChip(
                  label: const Text('Todos'),
                  selected: categoriaId == null,
                  onSelected: (_) => aoMudarCategoria(null),
                ),
              ),
              for (final c in catalogo.categorias)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: ChoiceChip(
                    label: Text(c.nome),
                    selected: categoriaId == c.id,
                    onSelected: (_) => aoMudarCategoria(c.id),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: itens.isEmpty
              ? const Center(child: Text('Nenhum item encontrado.'))
              : ListView.builder(
                  itemCount: itens.length,
                  itemBuilder: (context, i) {
                    final item = itens[i];
                    final local = catalogo.local(item.localPadraoId)?.nome;
                    final quantas = rascunho.totalDoItem(item.id);
                    return ListTile(
                      title: Text(item.nome),
                      subtitle: Text([
                        if (local != null) local,
                        item.origemSugerida == 'producao' ? 'produção' : 'compra',
                        if (item.controlaRecipiente) 'pesar cada recipiente',
                      ].join(' · ')),
                      trailing: quantas > 0
                          ? Badge(label: Text('$quantas'), child: const Icon(Icons.check_circle, color: Colors.green))
                          : const Icon(Icons.chevron_right),
                      onTap: () => mostrarItemEntrada(
                        context: context,
                        item: item,
                        rascunho: rascunho,
                        localNome: local,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
