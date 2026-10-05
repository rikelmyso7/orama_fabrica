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

/// Quanto há de cada item em cada local. Balde, cuba e pote mostram também quantos recipientes são,
/// e tocando neles se vê o peso, o lote e a validade de cada um.
class EstoquePage extends StatefulWidget {
  const EstoquePage({super.key});

  @override
  State<EstoquePage> createState() => _EstoquePageState();
}

class _EstoquePageState extends State<EstoquePage> {
  final _busca = TextEditingController();
  List<Saldo> _saldos = const [];
  bool _carregando = false;
  bool _soComAlerta = false;
  String? _aviso;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _carregar());
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
      final lista = await api.saldo();
      if (!mounted) return;
      setState(() {
        _saldos = lista;
        _aviso = null;
      });
    } on SemConexaoException catch (e) {
      if (mounted) setState(() => _aviso = '${e.mensagem} O saldo não foi carregado.');
    } on ApiException catch (e) {
      if (mounted) setState(() => _aviso = e.mensagem);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalogo = context.watch<CatalogoStore>().catalogo;
    final comAlerta = _saldos.where((s) => s.temDuvida).length;
    // Saldo zero só fica de fora se não há nada a conferir: uma contagem sem valor também tem saldo zero.
    final visiveis = _saldos
        .where((s) => s.saldoBase != 0 || s.saldoUnidades != 0 || s.temDuvida)
        .where((s) => !_soComAlerta || s.temDuvida)
        .where((s) => _busca.text.trim().isEmpty || Texto.contem(s.item, _busca.text))
        .toList();
    final porLocal = <String, List<Saldo>>{};
    for (final s in visiveis) {
      porLocal.putIfAbsent(s.local, () => []).add(s);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            controller: _busca,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar item',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        if (comAlerta > 0)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: FilterChip(
                avatar: Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800, size: 18),
                label: Text('Só com alerta ($comAlerta)'),
                selected: _soComAlerta,
                onSelected: (v) => setState(() => _soComAlerta = v),
              ),
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
                if (porLocal.isEmpty && !_carregando)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('Nenhum item com saldo.')),
                  ),
                for (final entrada in porLocal.entries)
                  ExpansionTile(
                    initiallyExpanded: true,
                    title: Text(entrada.key),
                    children: [
                      for (final s in entrada.value)
                        _SaldoTile(
                          saldo: s,
                          controlaRecipiente: catalogo?.item(s.itemId)?.controlaRecipiente ?? false,
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SaldoTile extends StatelessWidget {
  const _SaldoTile({required this.saldo, required this.controlaRecipiente});

  final Saldo saldo;
  final bool controlaRecipiente;

  @override
  Widget build(BuildContext context) {
    final s = saldo;
    final negativo = s.saldoBase < 0;
    final quantidade = Numero.formatarBase(s.saldoBase, s.unidadeBase);
    return ListTile(
      title: Text(s.variante == null ? s.item : '${s.item} · ${s.variante}'),
      subtitle:
          controlaRecipiente ? Text('${s.saldoUnidades} ${s.saldoUnidades == 1 ? 'recipiente' : 'recipientes'}') : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (s.temDuvida)
            AlertaDuvida(
              titulo: s.variante == null ? s.item : '${s.item} · ${s.variante}',
              motivos: s.motivosDaDuvida,
            ),
          Text(
            quantidade,
            style: TextStyle(fontWeight: FontWeight.w600, color: negativo ? Colors.red : null),
          ),
        ],
      ),
      onTap: controlaRecipiente
          ? () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                showDragHandle: true,
                builder: (_) => _RecipientesSheet(itemId: s.itemId, titulo: s.item),
              )
          : null,
    );
  }
}

class _RecipientesSheet extends StatefulWidget {
  const _RecipientesSheet({required this.itemId, required this.titulo});

  final String itemId;
  final String titulo;

  @override
  State<_RecipientesSheet> createState() => _RecipientesSheetState();
}

class _RecipientesSheetState extends State<_RecipientesSheet> {
  late final Future<List<Recipiente>> _futuro = context.read<OramaApi>().recipientes(widget.itemId);

  @override
  Widget build(BuildContext context) {
    final dia = DateFormat('dd/MM/yyyy');
    return FutureBuilder<List<Recipiente>>(
      future: _futuro,
      builder: (context, snapshot) {
        final Widget corpo;
        if (snapshot.connectionState != ConnectionState.done) {
          corpo = const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
        } else if (snapshot.hasError) {
          final erro = snapshot.error;
          corpo = Padding(
            padding: const EdgeInsets.all(24),
            child: Text(erro is ApiException ? erro.mensagem : 'Não foi possível carregar os recipientes.'),
          );
        } else {
          final lista = snapshot.data!;
          corpo = Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final r in lista)
                ListTile(
                  title: Text('${r.etiqueta} · ${Numero.formatarBase(r.pesoBase, 'g')}'),
                  subtitle: Text([
                    if (r.lote != null) 'Lote ${r.lote}',
                    'produzido em ${dia.format(r.produzidoEm)}',
                    if (r.validade != null) 'validade ${dia.format(r.validade!)}',
                  ].join(' · ')),
                ),
              if (lista.isEmpty)
                const Padding(padding: EdgeInsets.all(24), child: Text('Nenhum recipiente em estoque.')),
            ],
          );
        }
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text('${widget.titulo}: em ordem de saída (menor validade primeiro)',
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                corpo,
              ],
            ),
          ),
        );
      },
    );
  }
}
