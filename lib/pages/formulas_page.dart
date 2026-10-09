import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/models.dart';
import '../data/catalogo_store.dart';
import '../data/formulas_store.dart';
import '../util/numero.dart';
import '../util/texto.dart';

class FormulasPage extends StatelessWidget {
  const FormulasPage({super.key});

  @override
  Widget build(BuildContext context) {
    final catalogo = context.watch<CatalogoStore>();
    final formulas = context.watch<FormulasStore>().formulas;
    return Scaffold(
      appBar: AppBar(title: const Text('Fórmulas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed:
            catalogo.catalogo == null ? null : () => _abrirFormulario(context),
        icon: const Icon(Icons.add),
        label: const Text('Nova fórmula'),
      ),
      body: catalogo.catalogo == null
          ? _SemCatalogo(store: catalogo)
          : formulas.isEmpty
              ? const Center(child: Text('Nenhuma fórmula cadastrada.'))
              : ListView.builder(
                  itemCount: formulas.length,
                  itemBuilder: (context, i) {
                    final f = formulas[i];
                    return ListTile(
                      title: Text(f.itemProduzidoNome),
                      subtitle: Text(
                          '${f.linhas.length} ${f.linhas.length == 1 ? 'insumo' : 'insumos'}'),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => _abrirFormulario(context, f),
                    );
                  },
                ),
    );
  }

  Future<void> _abrirFormulario(BuildContext context, [FormulaItem? formula]) {
    return Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => FormulaFormPage(formula: formula)));
  }
}

class FormulaFormPage extends StatefulWidget {
  const FormulaFormPage({super.key, this.formula});

  final FormulaItem? formula;

  @override
  State<FormulaFormPage> createState() => _FormulaFormPageState();
}

class _FormulaFormPageState extends State<FormulaFormPage> {
  ItemCatalogo? _produto;
  late final List<LinhaFormula> _linhas =
      List.of(widget.formula?.linhas ?? const []);
  String? _erro;

  @override
  void initState() {
    super.initState();
    final catalogo = context.read<CatalogoStore>().catalogo;
    final id = widget.formula?.itemProduzidoId;
    if (catalogo != null && id != null) _produto = catalogo.item(id);
  }

  Future<void> _selecionarProduto() async {
    final item = await _escolherItem(context, titulo: 'Item produzido');
    if (item != null) setState(() => _produto = item);
  }

  Future<void> _adicionarLinha() async {
    final linha = await showModalBottomSheet<LinhaFormula>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: const _LinhaFormulaSheet(),
      ),
    );
    if (linha != null) setState(() => _linhas.add(linha));
  }

  Future<void> _salvar() async {
    final produto = _produto;
    if (produto == null) {
      setState(() => _erro = 'Escolha o item produzido.');
      return;
    }
    if (_linhas.isEmpty) {
      setState(() => _erro = 'Adicione pelo menos um insumo.');
      return;
    }
    await context.read<FormulasStore>().salvar(FormulaItem(
          itemProduzidoId: produto.id,
          itemProduzidoNome: produto.nome,
          linhas: List.of(_linhas),
        ));
    if (mounted) Navigator.pop(context);
  }

  Future<void> _removerFormula() async {
    final produto = _produto;
    if (produto == null) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover fórmula?'),
        content: Text('A fórmula de ${produto.nome} será removida.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remover')),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    await context.read<FormulasStore>().remover(produto.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title:
              Text(widget.formula == null ? 'Nova fórmula' : 'Editar fórmula')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Item produzido'),
            subtitle: Text(
                _produto?.nome ?? 'Escolha o item que esta fórmula produz'),
            trailing: const Icon(Icons.search),
            onTap: _selecionarProduto,
          ),
          const Divider(),
          Row(
            children: [
              Expanded(
                  child: Text('Insumos',
                      style: Theme.of(context).textTheme.titleMedium)),
              FilledButton.tonalIcon(
                  onPressed: _adicionarLinha,
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar')),
            ],
          ),
          if (_linhas.isEmpty)
            const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('Nenhum insumo informado.'))
          else
            for (var i = 0; i < _linhas.length; i++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_linhas[i].itemNome),
                subtitle: Text(Numero.formatar(
                    double.parse(_linhas[i].quantidade), _linhas[i].unidade)),
                trailing: IconButton(
                  tooltip: 'Remover insumo',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => setState(() => _linhas.removeAt(i)),
                ),
              ),
          if (_erro != null)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child:
                    Text(_erro!, style: TextStyle(color: Colors.red.shade800))),
          if (widget.formula != null) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
                onPressed: _removerFormula,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remover fórmula')),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(
              onPressed: _salvar, child: const Text('Salvar fórmula')),
        ),
      ),
    );
  }
}

class _LinhaFormulaSheet extends StatefulWidget {
  const _LinhaFormulaSheet();

  @override
  State<_LinhaFormulaSheet> createState() => _LinhaFormulaSheetState();
}

class _LinhaFormulaSheetState extends State<_LinhaFormulaSheet> {
  final _quantidade = TextEditingController();
  ItemCatalogo? _item;
  String _unidade = 'un';
  String? _erro;

  @override
  void dispose() {
    _quantidade.dispose();
    super.dispose();
  }

  Future<void> _selecionar() async {
    final item = await _escolherItem(context, titulo: 'Insumo');
    if (item != null) {
      setState(() {
        _item = item;
        _unidade = item.unidadesPermitidas.first;
      });
    }
  }

  void _confirmar() {
    final item = _item;
    final q = Numero.lerQuantidade(_quantidade.text);
    if (item == null) {
      setState(() => _erro = 'Escolha o insumo.');
      return;
    }
    if (q == null) {
      setState(() => _erro = 'Digite uma quantidade válida.');
      return;
    }
    Navigator.pop(
        context,
        LinhaFormula(
            itemId: item.id,
            itemNome: item.nome,
            quantidade: Numero.paraApi(q),
            unidade: _unidade));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Adicionar insumo',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Insumo'),
            subtitle: Text(_item?.nome ?? 'Escolha o item consumido'),
            trailing: const Icon(Icons.search),
            onTap: _selecionar,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _quantidade,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Quantidade', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _unidade,
                items: [
                  for (final u in _item?.unidadesPermitidas ?? const ['un'])
                    DropdownMenuItem(value: u, child: Text(u))
                ],
                onChanged: (u) => setState(() => _unidade = u ?? _unidade),
              ),
            ],
          ),
          if (_erro != null)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child:
                    Text(_erro!, style: TextStyle(color: Colors.red.shade800))),
          const SizedBox(height: 16),
          SizedBox(
              width: double.infinity,
              child: FilledButton(
                  onPressed: _confirmar, child: const Text('Adicionar'))),
        ],
      ),
    );
  }
}

Future<ItemCatalogo?> _escolherItem(BuildContext context,
    {required String titulo}) {
  return showModalBottomSheet<ItemCatalogo>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _EscolherItemSheet(titulo: titulo),
  );
}

class _EscolherItemSheet extends StatefulWidget {
  const _EscolherItemSheet({required this.titulo});

  final String titulo;

  @override
  State<_EscolherItemSheet> createState() => _EscolherItemSheetState();
}

class _EscolherItemSheetState extends State<_EscolherItemSheet> {
  final _busca = TextEditingController();

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalogo = context.watch<CatalogoStore>().catalogo;
    final itens = (catalogo?.itens ?? const <ItemCatalogo>[])
        .where((i) =>
            _busca.text.trim().isEmpty ||
            Texto.contem(i.nome, _busca.text) ||
            (i.sku != null && Texto.contem(i.sku!, _busca.text)))
        .toList()
      ..sort((a, b) =>
          Texto.normalizar(a.nome).compareTo(Texto.normalizar(b.nome)));
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _busca,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    labelText: widget.titulo,
                    border: const OutlineInputBorder()),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: itens.length,
                itemBuilder: (context, i) => ListTile(
                  title: Text(itens[i].nome),
                  subtitle: Text([
                    if (itens[i].sku != null) itens[i].sku!,
                    if (itens[i].grupoVisual.isNotEmpty) itens[i].grupoVisual
                  ].join(' · ')),
                  onTap: () => Navigator.pop(context, itens[i]),
                ),
              ),
            ),
          ],
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
