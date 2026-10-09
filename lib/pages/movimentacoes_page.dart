import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../api/orama_api.dart';
import '../data/catalogo_store.dart';
import '../util/numero.dart';
import '../util/texto.dart';
import '../widgets/alerta_duvida.dart';
import '../widgets/cabecalho_de_data.dart';

/// Consulta livre das movimentações registradas na API, com filtros e acesso ao rastreio por lote/operação.
class MovimentacoesPage extends StatefulWidget {
  const MovimentacoesPage({super.key, this.ativa = true});

  final bool ativa;

  @override
  State<MovimentacoesPage> createState() => _MovimentacoesPageState();
}

class _MovimentacoesPageState extends State<MovimentacoesPage> {
  final _busca = TextEditingController();
  late DateTime _de;
  late DateTime _ate;
  String? _localId;
  String? _itemId;
  List<Movimento> _movimentos = const [];
  bool _carregando = false;
  String? _aviso;
  bool _jaCarregou = false;

  static DateTime _dia(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _ate = _dia(DateTime.now());
    _de = _ate.subtract(const Duration(days: 6));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.ativa) _carregar();
    });
  }

  @override
  void didUpdateWidget(covariant MovimentacoesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ativa && !_jaCarregou) _carregar();
  }

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    final api = context.read<OramaApi>();
    setState(() => _carregando = true);
    try {
      final lista = await api.movimentos(
          de: _de, ate: _ate, localId: _localId, itemId: _itemId, limite: 500);
      if (!mounted) return;
      setState(() {
        _movimentos = lista;
        _aviso = null;
        _jaCarregou = true;
      });
    } on SemConexaoException catch (e) {
      if (mounted)
        setState(() =>
            _aviso = '${e.mensagem} As movimentações não foram carregadas.');
    } on ApiException catch (e) {
      if (mounted) setState(() => _aviso = e.mensagem);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _selecionarPeriodo() async {
    final intervalo = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _de, end: _ate),
      locale: const Locale('pt', 'BR'),
    );
    if (intervalo == null) return;
    setState(() {
      _de = _dia(intervalo.start);
      _ate = _dia(intervalo.end);
    });
    await _carregar();
  }

  /// Anda com o período inteiro para trás ou para frente, sem passar de hoje.
  void _deslocar(int sentido) {
    final dias = _ate.difference(_de).inDays + 1;
    final hoje = _dia(DateTime.now());
    var ate = _ate.add(Duration(days: dias * sentido));
    if (ate.isAfter(hoje)) ate = hoje;
    setState(() {
      _ate = ate;
      _de = ate.subtract(Duration(days: dias - 1));
    });
    _carregar();
  }

  void _limparFiltros() {
    setState(() {
      _ate = _dia(DateTime.now());
      _de = _ate.subtract(const Duration(days: 6));
      _localId = null;
      _itemId = null;
      _busca.clear();
    });
    _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final catalogo = context.watch<CatalogoStore>().catalogo;
    final data = DateFormat('dd/MM/yyyy');
    final busca = _busca.text;
    final visiveis = _movimentos
        .where((m) =>
            busca.trim().isEmpty ||
            Texto.contem(
                '${m.item} ${m.local} ${m.lote ?? ''} ${m.etiqueta ?? ''}',
                busca))
        .toList();

    return Column(
      children: [
        CabecalhoDeData(
          texto: _de == _ate
              ? data.format(_de)
              : '${data.format(_de)} – ${data.format(_ate)}',
          dicaAnterior: 'Período anterior',
          dicaProximo: 'Período seguinte',
          aoAnterior: () => _deslocar(-1),
          aoProximo:
              _ate.isBefore(_dia(DateTime.now())) ? () => _deslocar(1) : null,
          aoEscolher: _selecionarPeriodo,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: TextField(
            controller: _busca,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar por item, local, lote ou etiqueta',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownMenu<String?>(
                width: 210,
                label: const Text('Local'),
                initialSelection: _localId,
                dropdownMenuEntries: [
                  const DropdownMenuEntry<String?>(
                      value: null, label: 'Todos os locais'),
                  for (final l in catalogo?.locais ?? const <LocalEstoque>[])
                    DropdownMenuEntry<String?>(value: l.id, label: l.nome),
                ],
                onSelected: (v) {
                  setState(() => _localId = v);
                  _carregar();
                },
              ),
              DropdownMenu<String?>(
                width: 250,
                label: const Text('Item'),
                initialSelection: _itemId,
                dropdownMenuEntries: [
                  const DropdownMenuEntry<String?>(
                      value: null, label: 'Todos os itens'),
                  for (final i in catalogo?.itens ?? const <ItemCatalogo>[])
                    DropdownMenuEntry<String?>(value: i.id, label: i.nome),
                ],
                onSelected: (v) {
                  setState(() => _itemId = v);
                  _carregar();
                },
              ),
              TextButton.icon(
                  onPressed: _limparFiltros,
                  icon: const Icon(Icons.filter_alt_off),
                  label: const Text('Limpar')),
            ],
          ),
        ),
        if (_carregando) const LinearProgressIndicator(),
        if (_aviso != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Text(_aviso!, style: TextStyle(color: Colors.red.shade800)),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _carregar,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (visiveis.isEmpty && !_carregando)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child:
                        Center(child: Text('Nenhuma movimentação encontrada.')),
                  ),
                for (final m in visiveis) _MovimentacaoTile(movimento: m),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MovimentacaoTile extends StatelessWidget {
  const _MovimentacaoTile({required this.movimento});

  final Movimento movimento;

  @override
  Widget build(BuildContext context) {
    final m = movimento;
    final (icone, cor, rotulo) = switch (m.tipo) {
      'entrada' => (Icons.south_west, Colors.green, 'Entrada'),
      'saida' => (Icons.north_east, Colors.red, 'Saída'),
      _ => (Icons.tune, Colors.blueGrey, 'Ajuste'),
    };
    final data = DateFormat('dd/MM/yyyy HH:mm').format(m.ocorridoEm);
    final detalhes = [
      '$rotulo em $data',
      m.local,
      if (m.lote != null) 'lote ${m.lote}',
      if (m.etiqueta != null) m.etiqueta!,
      if (m.validade != null)
        'validade ${DateFormat('dd/MM/yyyy').format(m.validade!)}',
      if (m.responsavel != null) 'responsável ${m.responsavel}',
    ].join(' · ');

    return ListTile(
      leading: Icon(icone, color: cor),
      title: Text(m.variante == null ? m.item : '${m.item} · ${m.variante}'),
      subtitle: Text('${Numero.formatar(m.quantidade, m.unidade)}\n$detalhes'),
      isThreeLine: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (m.temDuvida)
            AlertaDuvida(
              titulo: m.variante == null ? m.item : '${m.item} · ${m.variante}',
              motivos: [m.revisar!.trim()],
              textoOriginal: m.textoOriginal,
            ),
          if (m.operationId != null || m.lote != null)
            const Icon(Icons.chevron_right),
        ],
      ),
      onTap: m.operationId == null && m.lote == null
          ? null
          : () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                showDragHandle: true,
                builder: (_) => _RastreioSheet(movimento: m),
              ),
    );
  }
}

class _RastreioSheet extends StatelessWidget {
  const _RastreioSheet({required this.movimento});

  final Movimento movimento;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Rastreabilidade',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(movimento.variante == null
                  ? movimento.item
                  : '${movimento.item} · ${movimento.variante}'),
              if (movimento.operationId != null)
                _OperacaoCard(id: movimento.operationId!),
              if (movimento.lote != null)
                _OrigemLoteCard(lote: movimento.lote!),
            ],
          ),
        ),
      ),
    );
  }
}

class _OperacaoCard extends StatelessWidget {
  const _OperacaoCard({required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<OperacaoDetalhe>(
      future: context.read<OramaApi>().operacao(id),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError)
          return const _ErroRastreio('Não foi possível carregar a operação.');
        final op = snapshot.data!;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Operação ${op.codigo}',
                    style: Theme.of(context).textTheme.titleMedium),
                Text([
                  op.tipo,
                  op.status,
                  op.local,
                  if (op.lotePrincipal != null) 'lote ${op.lotePrincipal}'
                ].join(' · ')),
                if (op.responsavel != null)
                  Text('Responsável: ${op.responsavel}'),
                if (op.observacao != null && op.observacao!.trim().isNotEmpty)
                  Text(op.observacao!),
                const SizedBox(height: 8),
                for (final m in op.movimentos)
                  Text(
                      '${m.tipo == 'saida' ? 'Consumiu' : 'Gerou'} ${Numero.formatar(m.quantidade, m.unidade)} de ${m.item}'),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OrigemLoteCard extends StatelessWidget {
  const _OrigemLoteCard({required this.lote});

  final String lote;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<LoteOrigem>>(
      future: context.read<OramaApi>().origemDoLote(lote),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError)
          return const _ErroRastreio(
              'Não foi possível carregar a origem do lote.');
        final origens = snapshot.data!;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Origem do lote $lote',
                    style: Theme.of(context).textTheme.titleMedium),
                if (origens.isEmpty)
                  const Text('Nenhum consumo vinculado a este lote.'),
                for (final o in origens)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(o.insumo),
                    subtitle: Text([
                      'consumiu ${Numero.formatar(o.qtdConsumidaBase, o.unidade)}',
                      if (o.loteInsumo != null) 'lote ${o.loteInsumo}',
                      o.local,
                    ].join(' · ')),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ErroRastreio extends StatelessWidget {
  const _ErroRastreio(this.mensagem);

  final String mensagem;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(12),
        child: Text(mensagem, style: TextStyle(color: Colors.red.shade800)),
      );
}
