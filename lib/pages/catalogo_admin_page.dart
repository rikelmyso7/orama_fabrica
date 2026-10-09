import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../api/orama_api.dart';
import '../data/catalogo_store.dart';
import 'item_form_page.dart';

/// Cadastro do catálogo: itens e categorias. Só o administrador chega aqui.
/// Nada é apagado: um item ou categoria tirado de uso some das telas, e o histórico fica.
class CatalogoAdminPage extends StatefulWidget {
  const CatalogoAdminPage({super.key});

  @override
  State<CatalogoAdminPage> createState() => _CatalogoAdminPageState();
}

class _CatalogoAdminPageState extends State<CatalogoAdminPage> {
  final _busca = TextEditingController();

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  Future<void> _abrirItem([ItemCatalogo? item]) => Navigator.of(context)
      .push<bool>(MaterialPageRoute(builder: (_) => ItemFormPage(item: item)));

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CatalogoStore>();
    final categorias = {
      for (final c in store.catalogo?.categorias ?? const <Categoria>[])
        c.id: c.nome
    };
    final itens = store.itens(busca: _busca.text);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Itens'),
        actions: [
          IconButton(
            tooltip: 'Categorias',
            icon: const Icon(Icons.category_outlined),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => const _CategoriasSheet(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirItem,
        icon: const Icon(Icons.add),
        label: const Text('Novo item'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _busca,
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar item',
                border: OutlineInputBorder()),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Expanded(
          child: itens.isEmpty
              ? const Center(child: Text('Nenhum item encontrado.'))
              : ListView.builder(
                  itemCount: itens.length,
                  itemBuilder: (_, i) {
                    final item = itens[i];
                    final detalhe = [
                      categorias[item.categoriaId],
                      item.grupoVisual,
                      item.unidadeBase
                    ]
                        .whereType<String>()
                        .where((t) => t.isNotEmpty)
                        .join(' · ');
                    return ListTile(
                      title: Text(item.nome),
                      subtitle: Text(detalhe),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => _abrirItem(item),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

class _CategoriasSheet extends StatelessWidget {
  const _CategoriasSheet();

  Future<String?> _pedirNome(BuildContext context,
      {String inicial = '', required String titulo}) {
    final controlador = TextEditingController(text: inicial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: TextField(
          controller: controlador,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nome da categoria'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controlador.text.trim()),
              child: const Text('Salvar')),
        ],
      ),
    );
  }

  Future<void> _executar(
      BuildContext context, Future<void> Function(OramaApi api) acao) async {
    final api = context.read<OramaApi>();
    final catalogo = context.read<CatalogoStore>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await acao(api);
      await catalogo.atualizar();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.mensagem)));
    } on SemConexaoException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.mensagem)));
    }
  }

  Future<void> _nova(BuildContext context) async {
    final nome = await _pedirNome(context, titulo: 'Nova categoria');
    if (nome == null || nome.isEmpty || !context.mounted) return;
    await _executar(context, (api) => api.criarCategoria(nome));
  }

  Future<void> _renomear(BuildContext context, Categoria c) async {
    final nome = await _pedirNome(context,
        inicial: c.nome, titulo: 'Renomear categoria');
    if (nome == null || nome.isEmpty || nome == c.nome || !context.mounted) {
      return;
    }
    await _executar(
        context, (api) => api.editarCategoria(c.id, nome: nome, ativo: true));
  }

  Future<void> _tirarDeUso(BuildContext context, Categoria c) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tirar categoria de uso?'),
        content: Text(
            '"${c.nome}" some das telas. Só é possível se ela não tiver itens ativos.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Tirar de uso')),
        ],
      ),
    );
    if (confirmar != true || !context.mounted) return;
    await _executar(context,
        (api) => api.editarCategoria(c.id, nome: c.nome, ativo: false));
  }

  @override
  Widget build(BuildContext context) {
    final categorias = context.watch<CatalogoStore>().catalogo?.categorias ??
        const <Categoria>[];
    return SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            title: const Text('Categorias'),
            trailing: FilledButton.icon(
              onPressed: () => _nova(context),
              icon: const Icon(Icons.add),
              label: const Text('Nova'),
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView(shrinkWrap: true, children: [
              for (final c in categorias)
                ListTile(
                  title: Text(c.nome),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      tooltip: 'Renomear ${c.nome}',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _renomear(context, c),
                    ),
                    IconButton(
                      tooltip: 'Tirar ${c.nome} de uso',
                      icon: const Icon(Icons.block),
                      onPressed: () => _tirarDeUso(context, c),
                    ),
                  ]),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}
