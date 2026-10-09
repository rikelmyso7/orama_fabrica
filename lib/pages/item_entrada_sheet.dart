import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/models.dart';
import '../data/rascunho_entrada.dart';
import '../util/numero.dart';

const _origens = {
  'producao': 'Produção',
  'compra': 'Compra',
  'devolucao': 'Devolução'
};

/// Faixa de peso esperada para um balde, cuba ou pote, em gramas. Fora dela o app pede confirmação:
/// o erro típico é a unidade (digitar 4100 kg querendo dizer 4100 g).
const pesoMinimoRecipiente = 100.0;
const pesoMaximoRecipiente = 20000.0;

bool pesoSuspeito(PesoDigitado p) {
  final gramas = p.unidade == 'kg' ? p.valor * 1000 : p.valor;
  return gramas < pesoMinimoRecipiente || gramas > pesoMaximoRecipiente;
}

Future<void> mostrarItemEntrada({
  required BuildContext context,
  required ItemCatalogo item,
  required RascunhoEntrada rascunho,
  String? localNome,
  String? localId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: ItemEntradaSheet(
          item: item,
          rascunho: rascunho,
          localNome: localNome,
          localId: localId),
    ),
  );
}

/// Formulário de um item. Item comum: quantidade e unidade. Balde, cuba e pote: lote, dia e uma
/// lista de pesos, um por recipiente (cada um vira uma linha, com o mesmo lote e dia).
class ItemEntradaSheet extends StatefulWidget {
  const ItemEntradaSheet(
      {super.key,
      required this.item,
      required this.rascunho,
      this.localNome,
      this.localId});

  final ItemCatalogo item;
  final RascunhoEntrada rascunho;
  final String? localNome;
  final String? localId;

  @override
  State<ItemEntradaSheet> createState() => _ItemEntradaSheetState();
}

class _ItemEntradaSheetState extends State<ItemEntradaSheet> {
  final _quantidade = TextEditingController();
  final _peso = TextEditingController();
  final _lote = TextEditingController();
  final _documento = TextEditingController();
  final _pesos = <PesoDigitado>[];

  late String _origem = widget.item.origemSugerida;
  late String _unidade = widget.item.controlaRecipiente
      ? 'g'
      : widget.item.unidadesPermitidas.first;
  late DateTime _dia = _hoje();
  Variacao? _variacao;
  DateTime? _validade;
  String? _erro;

  ItemCatalogo get _item => widget.item;

  static DateTime _hoje() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void dispose() {
    _quantidade.dispose();
    _peso.dispose();
    _lote.dispose();
    _documento.dispose();
    super.dispose();
  }

  Future<DateTime?> _escolherData(
      {required DateTime inicial,
      required DateTime primeira,
      required DateTime ultima}) {
    return showDatePicker(
        context: context,
        initialDate: inicial,
        firstDate: primeira,
        lastDate: ultima);
  }

  Future<void> _escolherDia() async {
    final hoje = _hoje();
    final d = await _escolherData(
      inicial: _dia,
      primeira: hoje.subtract(const Duration(days: 30)),
      ultima: hoje,
    );
    if (d != null) setState(() => _dia = d);
  }

  Future<void> _escolherValidade() async {
    final hoje = _hoje();
    final d = await _escolherData(
      inicial: _validade ?? hoje.add(const Duration(days: 30)),
      primeira: hoje.subtract(const Duration(days: 365)),
      ultima: hoje.add(const Duration(days: 365 * 5)),
    );
    if (d != null) setState(() => _validade = d);
  }

  Future<void> _adicionarPeso() async {
    final v = Numero.lerQuantidade(_peso.text);
    if (v == null) {
      setState(() => _erro = 'Digite um peso válido, por exemplo 4,1.');
      return;
    }
    final p = PesoDigitado(v, _unidade);
    if (pesoSuspeito(p)) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Peso fora do esperado'),
          content: Text(
              '${Numero.formatar(p.valor, p.unidade)} é muito diferente do normal para um recipiente. '
              'Confira a unidade (g ou kg).'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Corrigir')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Está certo')),
          ],
        ),
      );
      if (confirmar != true || !mounted) return;
    }
    setState(() {
      _pesos.add(p);
      _peso.clear();
      _erro = null;
    });
  }

  bool _faltaVariacao() => _item.variacoes.isNotEmpty && _variacao == null;

  void _confirmarComum() {
    final q = Numero.lerQuantidade(_quantidade.text);
    if (q == null) {
      setState(() => _erro = 'Digite uma quantidade válida, maior que zero.');
      return;
    }
    if (_faltaVariacao()) {
      setState(() => _erro = 'Escolha a variação.');
      return;
    }
    widget.rascunho.adicionarComum(
      item: _item,
      quantidade: q,
      unidade: _unidade,
      origem: _origem,
      variacao: _variacao,
      localNome: widget.localNome,
      localId: widget.localId,
      lote: _lote.text.trim().isEmpty ? null : _lote.text.trim(),
      validade: _validade,
      documento: _origem == 'compra' ? _documento.text : null,
      textoOriginal: _quantidade.text.trim(),
    );
    Navigator.pop(context);
  }

  void _confirmarRecipientes() {
    if (_lote.text.trim().isEmpty) {
      setState(() => _erro = 'Informe o lote que está na etiqueta.');
      return;
    }
    if (_pesos.isEmpty) {
      setState(() => _erro = 'Adicione o peso de pelo menos um recipiente.');
      return;
    }
    if (_faltaVariacao()) {
      setState(() => _erro = 'Escolha a variação.');
      return;
    }
    widget.rascunho.adicionarRecipientes(
      item: _item,
      pesos: List.of(_pesos),
      lote: _lote.text,
      dia: _dia,
      origem: _origem,
      variacao: _variacao,
      localNome: widget.localNome,
      localId: widget.localId,
      validade: _validade,
    );
    Navigator.pop(context);
  }

  Widget _botaoData(String rotulo, DateTime? valor, VoidCallback aoTocar,
      {VoidCallback? aoLimpar}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(rotulo),
      subtitle: Text(valor == null
          ? 'Não informada'
          : DateFormat('dd/MM/yyyy').format(valor)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (aoLimpar != null && valor != null)
            IconButton(
                tooltip: 'Limpar',
                icon: const Icon(Icons.clear),
                onPressed: aoLimpar),
          IconButton(
              tooltip: 'Escolher data',
              icon: const Icon(Icons.calendar_today),
              onPressed: aoTocar),
        ],
      ),
      onTap: aoTocar,
    );
  }

  @override
  Widget build(BuildContext context) {
    final recipiente = _item.controlaRecipiente;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_item.nome, style: Theme.of(context).textTheme.titleMedium),
          if (widget.localNome != null) Text('Entra em: ${widget.localNome}'),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: [
              for (final e in _origens.entries)
                ButtonSegment(value: e.key, label: Text(e.value))
            ],
            selected: {_origem},
            onSelectionChanged: (s) => setState(() => _origem = s.first),
          ),
          if (_item.variacoes.isNotEmpty) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<Variacao>(
              initialValue: _variacao,
              decoration: const InputDecoration(
                  labelText: 'Variação', border: OutlineInputBorder()),
              items: [
                for (final v in _item.variacoes)
                  DropdownMenuItem(value: v, child: Text(v.rotulo))
              ],
              onChanged: (v) => setState(() => _variacao = v),
            ),
          ],
          const SizedBox(height: 12),
          if (recipiente) ..._camposRecipiente() else ..._camposComuns(),
          if (_erro != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_erro!, style: TextStyle(color: Colors.red.shade800)),
            ),
        ],
      ),
    );
  }

  List<Widget> _camposComuns() => [
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('campo-quantidade'),
                controller: _quantidade,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Quantidade', border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 12),
            DropdownButton<String>(
              key: const Key('campo-unidade'),
              value: _unidade,
              items: [
                for (final u in _item.unidadesPermitidas)
                  DropdownMenuItem(value: u, child: Text(u))
              ],
              onChanged: (u) => setState(() => _unidade = u ?? _unidade),
            ),
          ],
        ),
        if (_item.controlaValidade) ...[
          const SizedBox(height: 12),
          TextField(
            key: const Key('campo-lote'),
            controller: _lote,
            decoration: const InputDecoration(
                labelText: 'Lote (opcional)', border: OutlineInputBorder()),
          ),
          _botaoData('Validade (opcional)', _validade, _escolherValidade,
              aoLimpar: () => setState(() => _validade = null)),
        ],
        if (_origem == 'compra') ...[
          const SizedBox(height: 12),
          TextField(
            controller: _documento,
            decoration: const InputDecoration(
                labelText: 'Nota fiscal (opcional)',
                border: OutlineInputBorder()),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
              onPressed: _confirmarComum, child: const Text('Adicionar')),
        ),
      ];

  List<Widget> _camposRecipiente() => [
        TextField(
          key: const Key('campo-lote'),
          controller: _lote,
          decoration: const InputDecoration(
              labelText: 'Lote (o mesmo da etiqueta)',
              border: OutlineInputBorder()),
        ),
        _botaoData('Dia da produção', _dia, _escolherDia),
        if (_item.controlaValidade)
          _botaoData('Validade (opcional)', _validade, _escolherValidade,
              aoLimpar: () => setState(() => _validade = null)),
        const SizedBox(height: 4),
        Text('Peso de cada recipiente',
            style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('campo-peso'),
                controller: _peso,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onSubmitted: (_) => _adicionarPeso(),
                decoration: const InputDecoration(
                    labelText: 'Peso', border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 12),
            DropdownButton<String>(
              key: const Key('campo-unidade'),
              value: _unidade,
              items: const [
                DropdownMenuItem(value: 'g', child: Text('g')),
                DropdownMenuItem(value: 'kg', child: Text('kg')),
              ],
              onChanged: (u) => setState(() => _unidade = u ?? _unidade),
            ),
            IconButton.filledTonal(
              key: const Key('adicionar-peso'),
              tooltip: 'Adicionar peso',
              icon: const Icon(Icons.add),
              onPressed: _adicionarPeso,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (var i = 0; i < _pesos.length; i++)
              InputChip(
                label:
                    Text(Numero.formatar(_pesos[i].valor, _pesos[i].unidade)),
                onDeleted: () => setState(() => _pesos.removeAt(i)),
              ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _confirmarRecipientes,
            child: Text(_pesos.isEmpty
                ? 'Adicionar'
                : 'Adicionar ${_pesos.length} ${_pesos.length == 1 ? 'recipiente' : 'recipientes'}'),
          ),
        ),
      ];
}
