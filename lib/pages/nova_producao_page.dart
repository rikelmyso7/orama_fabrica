import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../api/orama_api.dart';
import '../auth/auth_store.dart';
import '../data/catalogo_store.dart';
import '../data/fila_operacoes.dart';
import '../data/operacao_pendente.dart';
import '../util/numero.dart';
import '../util/texto.dart';
import 'resumo_entrada_page.dart';

class NovaProducaoPage extends StatefulWidget {
  const NovaProducaoPage({super.key});

  @override
  State<NovaProducaoPage> createState() => _NovaProducaoPageState();
}

class _NovaProducaoPageState extends State<NovaProducaoPage> {
  final _uuid = const Uuid();
  final _lote = TextEditingController();
  final _observacao = TextEditingController();
  final _movimentos = <LinhaOperacaoPendente>[];
  String? _localId;
  bool _carregandoLote = false;
  bool _salvando = false;
  String? _aviso;

  @override
  void initState() {
    super.initState();
    final catalogo = context.read<CatalogoStore>();
    if (catalogo.catalogo == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => catalogo.atualizar());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _buscarLoteSugerido());
  }

  @override
  void dispose() {
    _lote.dispose();
    _observacao.dispose();
    super.dispose();
  }

  Future<void> _buscarLoteSugerido() async {
    setState(() => _carregandoLote = true);
    try {
      final lote = await context.read<OramaApi>().loteSugerido();
      if (mounted && _lote.text.trim().isEmpty) {
        _lote.text = lote;
      }
    } on SemConexaoException {
      if (mounted) {
        setState(() => _aviso =
            'Sem conexão: informe o lote ou salve para enviar depois.');
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _aviso = e.mensagem);
      }
    } finally {
      if (mounted) {
        setState(() => _carregandoLote = false);
      }
    }
  }

  bool get _temConsumo => _movimentos.any((e) => e.tipo == 'saida');
  bool get _temEntrada => _movimentos.any((e) => e.tipo == 'entrada');

  Future<void> _adicionarLinha(String tipo) async {
    final catalogo = context.read<CatalogoStore>().catalogo;
    if (catalogo == null) return;
    final linha = await showModalBottomSheet<LinhaOperacaoPendente>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: _LinhaProducaoSheet(
            tipo: tipo,
            catalogo: catalogo,
            uuid: _uuid,
            lotePadrao: _lote.text.trim()),
      ),
    );
    if (linha != null) setState(() => _movimentos.add(linha));
  }

  Future<void> _salvar() async {
    final usuario = context.read<AuthStore>().usuario;
    final catalogo = context.read<CatalogoStore>().catalogo;
    final local = catalogo?.local(_localId);
    if (usuario == null || catalogo == null || local == null) return;
    if (!_temConsumo || !_temEntrada) {
      setState(
          () => _aviso = 'Informe pelo menos um consumo e um produto gerado.');
      return;
    }
    setState(() => _salvando = true);
    final fila = context.read<FilaOperacoes>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final operacao = OperacaoPendente(
      id: _uuid.v4(),
      usuarioId: usuario.id,
      tipo: 'producao',
      localId: local.id,
      localNome: local.nome,
      responsavelId: usuario.id,
      responsavelNome: usuario.nome,
      lotePrincipal: _lote.text.trim().isEmpty ? null : _lote.text.trim(),
      iniciadaEm: DateTime.now(),
      observacao: _observacao.text,
      movimentos: List.of(_movimentos),
    );
    await fila.adicionar(operacao);
    final resultado = await fila.enviar(usuario.id);
    navigator.popUntil((rota) => rota.isFirst);
    messenger
        .showSnackBar(SnackBar(content: Text(mensagemDoEnvio(resultado, 1))));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CatalogoStore>();
    final catalogo = store.catalogo;
    final usuario = context.watch<AuthStore>().usuario;
    if (catalogo != null && _localId == null && catalogo.locais.isNotEmpty) {
      _localId = catalogo.locais.first.id;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Nova produção')),
      body: catalogo == null
          ? _SemCatalogoProducao(store: store)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_aviso != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    color: Colors.orange.shade50,
                    child: Text(_aviso!,
                        style: TextStyle(color: Colors.orange.shade900)),
                  ),
                DropdownButtonFormField<String>(
                  initialValue: _localId,
                  decoration: const InputDecoration(
                      labelText: 'Local da operação',
                      border: OutlineInputBorder()),
                  items: [
                    for (final l in catalogo.locais)
                      DropdownMenuItem(value: l.id, child: Text(l.nome))
                  ],
                  onChanged: (v) => setState(() => _localId = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _lote,
                  decoration: InputDecoration(
                    labelText: 'Lote principal AAMMDDNN',
                    border: const OutlineInputBorder(),
                    suffixIcon: _carregandoLote
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : IconButton(
                            tooltip: 'Buscar lote sugerido',
                            icon: const Icon(Icons.refresh),
                            onPressed: _buscarLoteSugerido),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text('Responsável: ${usuario?.nome ?? ''}'),
                    subtitle: Text('Registrado por: ${usuario?.nome ?? ''}'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _observacao,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                      labelText: 'Observação (opcional)',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                _SecaoMovimentos(
                  titulo: 'Consumos',
                  vazio: 'Nenhum insumo consumido.',
                  linhas: _movimentos.where((e) => e.tipo == 'saida').toList(),
                  aoAdicionar: () => _adicionarLinha('saida'),
                  aoRemover: (id) => setState(
                      () => _movimentos.removeWhere((e) => e.id == id)),
                ),
                const SizedBox(height: 12),
                _SecaoMovimentos(
                  titulo: 'Produtos gerados',
                  vazio: 'Nenhum produto gerado.',
                  linhas:
                      _movimentos.where((e) => e.tipo == 'entrada').toList(),
                  aoAdicionar: () => _adicionarLinha('entrada'),
                  aoRemover: (id) => setState(
                      () => _movimentos.removeWhere((e) => e.id == id)),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: (_salvando || catalogo == null || _localId == null)
                ? null
                : _salvar,
            icon: _salvando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined),
            label: Text('Salvar produção (${_movimentos.length})'),
          ),
        ),
      ),
    );
  }
}

class _SemCatalogoProducao extends StatelessWidget {
  const _SemCatalogoProducao({required this.store});

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

class _SecaoMovimentos extends StatelessWidget {
  const _SecaoMovimentos({
    required this.titulo,
    required this.vazio,
    required this.linhas,
    required this.aoAdicionar,
    required this.aoRemover,
  });

  final String titulo;
  final String vazio;
  final List<LinhaOperacaoPendente> linhas;
  final VoidCallback aoAdicionar;
  final void Function(String id) aoRemover;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(titulo,
                        style: Theme.of(context).textTheme.titleMedium)),
                FilledButton.tonalIcon(
                    onPressed: aoAdicionar,
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar')),
              ],
            ),
            if (linhas.isEmpty)
              Padding(
                  padding: const EdgeInsets.only(top: 8), child: Text(vazio))
            else
              for (final l in linhas)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.itemNome),
                  subtitle: Text([
                    l.descricao,
                    if (l.varianteRotulo != null) l.varianteRotulo!,
                    if (l.lote != null && l.lote!.isNotEmpty) 'lote ${l.lote}',
                    DateFormat('dd/MM HH:mm').format(l.ocorridoEm),
                  ].join(' · ')),
                  trailing: IconButton(
                    tooltip: 'Remover',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => aoRemover(l.id),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _LinhaProducaoSheet extends StatefulWidget {
  const _LinhaProducaoSheet(
      {required this.tipo,
      required this.catalogo,
      required this.uuid,
      required this.lotePadrao});

  final String tipo;
  final Catalogo catalogo;
  final Uuid uuid;
  final String lotePadrao;

  @override
  State<_LinhaProducaoSheet> createState() => _LinhaProducaoSheetState();
}

class _LinhaProducaoSheetState extends State<_LinhaProducaoSheet> {
  final _busca = TextEditingController();
  final _quantidade = TextEditingController();
  final _lote = TextEditingController();
  ItemCatalogo? _item;
  Variacao? _variacao;
  String _unidade = 'un';
  String? _erro;

  @override
  void initState() {
    super.initState();
    _lote.text = widget.tipo == 'entrada' ? widget.lotePadrao : '';
  }

  @override
  void dispose() {
    _busca.dispose();
    _quantidade.dispose();
    _lote.dispose();
    super.dispose();
  }

  void _selecionar(ItemCatalogo item) {
    setState(() {
      _item = item;
      _variacao = null;
      _unidade = item.controlaRecipiente ? 'g' : item.unidadesPermitidas.first;
    });
  }

  void _confirmar() {
    final item = _item;
    final q = Numero.lerQuantidade(_quantidade.text);
    if (item == null) {
      setState(() => _erro = 'Escolha o item.');
      return;
    }
    if (q == null) {
      setState(() => _erro = 'Digite uma quantidade válida.');
      return;
    }
    if (item.variacoes.isNotEmpty && _variacao == null) {
      setState(() => _erro = 'Escolha a variação.');
      return;
    }
    Navigator.pop(
      context,
      LinhaOperacaoPendente(
        id: widget.uuid.v4(),
        tipo: widget.tipo,
        itemId: item.id,
        itemNome: item.nome,
        varianteId: _variacao?.id,
        varianteRotulo: _variacao?.rotulo,
        quantidade: Numero.paraApi(q),
        unidade: _unidade,
        unidades:
            item.controlaRecipiente || item.unidadeBase == 'un' ? 1 : null,
        lote: _lote.text.trim().isEmpty ? null : _lote.text.trim(),
        textoOriginal: _quantidade.text.trim(),
        ocorridoEm: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final itens = widget.catalogo.itens
        .where((i) =>
            _busca.text.trim().isEmpty || Texto.contem(i.nome, _busca.text))
        .toList()
      ..sort((a, b) =>
          Texto.normalizar(a.nome).compareTo(Texto.normalizar(b.nome)));
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              widget.tipo == 'saida'
                  ? 'Adicionar consumo'
                  : 'Adicionar produto gerado',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _busca,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Buscar item',
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 180,
            child: ListView.builder(
              itemCount: itens.length,
              itemBuilder: (context, i) {
                final item = itens[i];
                Categoria? categoria;
                for (final c in widget.catalogo.categorias) {
                  if (c.id == item.categoriaId) {
                    categoria = c;
                    break;
                  }
                }
                final selecionado = _item?.id == item.id;
                return ListTile(
                  selected: selecionado,
                  leading: Icon(selecionado
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked),
                  onTap: () => _selecionar(item),
                  title: Text(item.nome),
                  subtitle: Text([
                    if (item.sku != null) item.sku!,
                    if (categoria != null) categoria.nome,
                    if (item.grupoVisual.isNotEmpty) item.grupoVisual,
                  ].join(' · ')),
                );
              },
            ),
          ),
          if (_item?.variacoes.isNotEmpty ?? false) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<Variacao>(
              initialValue: _variacao,
              decoration: const InputDecoration(
                  labelText: 'Variação', border: OutlineInputBorder()),
              items: [
                for (final v in _item!.variacoes)
                  DropdownMenuItem(value: v, child: Text(v.rotulo))
              ],
              onChanged: (v) => setState(() => _variacao = v),
            ),
          ],
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
          const SizedBox(height: 12),
          TextField(
            controller: _lote,
            decoration: InputDecoration(
              labelText: widget.tipo == 'saida'
                  ? 'Lote consumido (opcional)'
                  : 'Lote produzido',
              border: const OutlineInputBorder(),
            ),
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
