import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../auth/auth_store.dart';
import '../data/catalogo_store.dart';
import '../data/formulas_store.dart';
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

  @override
  void initState() {
    super.initState();
    _rascunho =
        RascunhoEntrada(usuarioId: context.read<AuthStore>().usuario!.id);
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
        content: Text(
            'Você tem ${_rascunho.total} ${_rascunho.total == 1 ? 'linha' : 'linhas'} que ainda não foram salvas.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Continuar editando')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Descartar')),
        ],
      ),
    );
    return sair ?? false;
  }

  void _revisar() {
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ResumoEntradaPage(rascunho: _rascunho)));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CatalogoStore>();
    final formulas = context.watch<FormulasStore>();
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
        child: catalogo == null
            ? _tela(body: _SemCatalogo(store: store))
            : DefaultTabController(
                // uma aba por categoria, mais "Todos"; o tamanho muda se o catálogo for atualizado
                key: ValueKey(catalogo.categorias.length),
                length: catalogo.categorias.length + 1,
                child: _tela(
                  abas: [
                    const Tab(text: 'Todos'),
                    for (final c in catalogo.categorias) Tab(text: c.nome),
                  ],
                  body: _Corpo(
                    catalogo: catalogo,
                    formulas: formulas,
                    store: store,
                    busca: _busca,
                    rascunho: _rascunho,
                    aoBuscar: () => setState(() {}),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _tela({required Widget body, List<Tab>? abas}) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova entrada'),
        // maybePop respeita o aviso de "descartar entrada?" (PopScope)
        leading: BackButton(onPressed: () => Navigator.of(context).maybePop()),
        bottom: abas == null
            ? null
            : TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.amber,
                tabs: abas,
              ),
      ),
      body: body,
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
                  Text(
                      store.aviso ??
                          'O catálogo de itens ainda não foi carregado.',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                      onPressed: store.atualizar,
                      child: const Text('Tentar de novo')),
                ],
              ),
      ),
    );
  }
}

class _Corpo extends StatelessWidget {
  const _Corpo({
    required this.catalogo,
    required this.formulas,
    required this.store,
    required this.busca,
    required this.rascunho,
    required this.aoBuscar,
  });

  final Catalogo catalogo;
  final FormulasStore formulas;
  final CatalogoStore store;
  final TextEditingController busca;
  final RascunhoEntrada rascunho;
  final VoidCallback aoBuscar;

  @override
  Widget build(BuildContext context) {
    final categorias = [null, ...catalogo.categorias.map((c) => c.id)];
    return Column(
      children: [
        if (store.aviso != null)
          Container(
            width: double.infinity,
            color: Colors.orange.shade50,
            padding: const EdgeInsets.all(8),
            child: Text(store.aviso!,
                style: TextStyle(color: Colors.orange.shade900)),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 4),
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
        Expanded(
          child: TabBarView(
            children: [
              for (final categoriaId in categorias)
                _ListaDeItens(
                  catalogo: catalogo,
                  formulas: formulas,
                  itens:
                      store.itens(categoriaId: categoriaId, busca: busca.text),
                  rascunho: rascunho,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ListaDeItens extends StatelessWidget {
  const _ListaDeItens(
      {required this.catalogo,
      required this.formulas,
      required this.itens,
      required this.rascunho});

  final Catalogo catalogo;
  final FormulasStore formulas;
  final List<ItemCatalogo> itens;
  final RascunhoEntrada rascunho;

  @override
  Widget build(BuildContext context) {
    if (itens.isEmpty) {
      return const Center(child: Text('Nenhum item encontrado.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: itens.length,
      itemBuilder: (context, i) {
        final item = itens[i];
        final local = catalogo.local(item.localPadraoId)?.nome;
        final temFormula = formulas.temFormula(item.id);
        final quantas = rascunho.totalDoItem(item.id);
        Categoria? categoria;
        for (final c in catalogo.categorias) {
          if (c.id == item.categoriaId) {
            categoria = c;
            break;
          }
        }
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            title: Text(
              [if (item.sku != null) item.sku!, item.nome].join(' · '),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            subtitle: Text([
              if (categoria != null) categoria.nome,
              if (item.grupoVisual.isNotEmpty) item.grupoVisual,
              if (local != null) local,
              item.origemSugerida == 'producao' ? 'produção' : 'compra',
              if (temFormula) 'tem fórmula',
              if (item.controlaRecipiente) 'pesar cada recipiente',
            ].join(' · ')),
            trailing: quantas > 0
                ? Badge(
                    label: Text('$quantas'),
                    child: const Icon(Icons.check_circle, color: Colors.green))
                : const Icon(Icons.chevron_right),
            onTap: () => mostrarItemEntrada(
              context: context,
              item: item,
              rascunho: rascunho,
              localNome: local,
              localId: item.localPadraoId,
            ),
          ),
        );
      },
    );
  }
}
