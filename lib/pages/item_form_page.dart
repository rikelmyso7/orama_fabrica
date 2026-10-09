import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../api/dados_item.dart';
import '../api/models.dart';
import '../api/orama_api.dart';
import '../data/catalogo_store.dart';
import '../util/numero.dart';

const _niveis = {
  'producao': 'Produção (feito na fábrica)',
  'terceiros': 'Terceiros (comprado)'
};
const _temperaturas = {
  'congelado': 'Congelado',
  'refrigerado': 'Refrigerado',
  'seco': 'Seco'
};
const _destinos = {
  'producao': 'Consumido na fábrica',
  'loja': 'Enviado à loja'
};
const _unidades = {
  'g': 'Gramas (g)',
  'ml': 'Mililitros (ml)',
  'un': 'Unidades (un)'
};

class _LinhaEmbalagem {
  _LinhaEmbalagem({String nome = '', String qtd = ''})
      : nome = TextEditingController(text: nome),
        qtd = TextEditingController(text: qtd);

  final TextEditingController nome;
  final TextEditingController qtd;

  void descartar() {
    nome.dispose();
    qtd.dispose();
  }
}

/// Cria ou edita um item do catálogo. Só o administrador chega aqui.
class ItemFormPage extends StatefulWidget {
  const ItemFormPage({super.key, this.item});

  /// Nulo = item novo.
  final ItemCatalogo? item;

  @override
  State<ItemFormPage> createState() => _ItemFormPageState();
}

class _ItemFormPageState extends State<ItemFormPage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _nome;
  late final TextEditingController _subgrupo;
  late final TextEditingController _tamanho;
  late final List<_LinhaEmbalagem> _embalagens;
  String? _categoriaId;
  late String _unidade;
  String? _nivel;
  String? _temperatura;
  String? _destino;
  late bool _validade;
  late bool _recipiente;
  bool _salvando = false;

  bool get _editando => widget.item != null;

  @override
  void initState() {
    super.initState();
    final i = widget.item;
    _nome = TextEditingController(text: i?.nome ?? '');
    _subgrupo = TextEditingController(text: i?.subgrupo ?? '');
    _tamanho = TextEditingController(text: i?.tamanho ?? '');
    _embalagens = [
      for (final e in i?.embalagens ?? const <Embalagem>[])
        _LinhaEmbalagem(nome: e.embalagem, qtd: Numero.paraApi(e.qtdBase)),
    ];
    _categoriaId = i?.categoriaId;
    _unidade = i?.unidadeBase ?? 'g';
    _nivel = i?.nivel;
    _temperatura = i?.temperatura;
    _destino = i?.destino;
    _validade = i?.controlaValidade ?? false;
    _recipiente = i?.controlaRecipiente ?? false;
  }

  @override
  void dispose() {
    _nome.dispose();
    _subgrupo.dispose();
    _tamanho.dispose();
    for (final e in _embalagens) {
      e.descartar();
    }
    super.dispose();
  }

  String? _vazioParaNulo(String texto) =>
      texto.trim().isEmpty ? null : texto.trim();

  DadosItem _dados() => DadosItem(
        nome: _nome.text,
        categoriaId: _categoriaId ?? '',
        unidadeBase: _unidade,
        subgrupo: _vazioParaNulo(_subgrupo.text),
        tamanho: _vazioParaNulo(_tamanho.text),
        nivel: _nivel,
        temperatura: _temperatura,
        destino: _destino,
        controlaValidade: _validade,
        controlaRecipiente: _recipiente,
        embalagens: [
          for (final e in _embalagens)
            if (e.nome.text.trim().isNotEmpty)
              Embalagem(
                embalagem: e.nome.text.trim(),
                qtdBase: Numero.lerQuantidade(e.qtd.text) ?? 0,
              ),
        ],
      );

  Future<void> _executar(Future<void> Function(OramaApi api) acao) async {
    final api = context.read<OramaApi>();
    final catalogo = context.read<CatalogoStore>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _salvando = true);
    try {
      await acao(api);
      await catalogo.atualizar();
      navigator.pop(true);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.mensagem)));
    } on SemConexaoException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.mensagem)));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _salvar() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final dados = _dados();
    final item = widget.item;
    await _executar((api) =>
        item == null ? api.criarItem(dados) : api.editarItem(item.id, dados));
  }

  Future<void> _inativar() async {
    final item = widget.item;
    if (item == null) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tirar item de uso?'),
        content: Text(
            '"${item.nome}" some das telas de entrada e produção. O histórico de '
            'movimentos continua guardado. Só é possível se o saldo estiver zerado.'),
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
    if (confirmar != true) return;
    await _executar((api) => api.editarItem(item.id, _dados(), ativo: false));
  }

  Widget _lista(String rotulo, Map<String, String> opcoes, String? valor,
      ValueChanged<String?> aoMudar,
      {bool obrigatorio = false}) {
    return DropdownButtonFormField<String>(
      initialValue: valor,
      isExpanded: true,
      decoration: InputDecoration(labelText: rotulo),
      items: [
        if (!obrigatorio)
          const DropdownMenuItem<String>(
              value: null, child: Text('Não definido')),
        for (final e in opcoes.entries)
          DropdownMenuItem(value: e.key, child: Text(e.value)),
      ],
      onChanged: _salvando ? null : aoMudar,
    );
  }

  @override
  Widget build(BuildContext context) {
    final categorias = context.watch<CatalogoStore>().catalogo?.categorias ??
        const <Categoria>[];
    return Scaffold(
      appBar: AppBar(title: Text(_editando ? 'Editar item' : 'Novo item')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nome,
              enabled: !_salvando,
              decoration: const InputDecoration(labelText: 'Nome'),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Informe o nome.' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _categoriaId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Categoria'),
              items: [
                for (final c in categorias)
                  DropdownMenuItem(value: c.id, child: Text(c.nome))
              ],
              onChanged:
                  _salvando ? null : (v) => setState(() => _categoriaId = v),
              validator: (v) => v == null ? 'Escolha a categoria.' : null,
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _subgrupo,
                  enabled: !_salvando,
                  decoration:
                      const InputDecoration(labelText: 'Subgrupo (opcional)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _tamanho,
                  enabled: !_salvando,
                  decoration:
                      const InputDecoration(labelText: 'Tamanho (opcional)'),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            if (_editando)
              InputDecorator(
                decoration: const InputDecoration(
                    labelText: 'Unidade base',
                    helperText:
                        'Não muda depois de criado: o saldo depende dela.'),
                child: Text(_unidades[_unidade] ?? _unidade),
              )
            else
              _lista('Unidade base', _unidades, _unidade,
                  (v) => setState(() => _unidade = v ?? 'g'),
                  obrigatorio: true),
            const SizedBox(height: 12),
            _lista('Nível', _niveis, _nivel, (v) => setState(() => _nivel = v)),
            const SizedBox(height: 12),
            _lista('Temperatura (define onde entra)', _temperaturas,
                _temperatura, (v) => setState(() => _temperatura = v)),
            const SizedBox(height: 12),
            _lista('Destino', _destinos, _destino,
                (v) => setState(() => _destino = v)),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Controla validade'),
              value: _validade,
              onChanged:
                  _salvando ? null : (v) => setState(() => _validade = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Controla recipiente (balde, cuba, pote)'),
              subtitle: const Text(
                  'Cada recipiente é pesado e controlado individualmente.'),
              value: _recipiente,
              onChanged:
                  _salvando ? null : (v) => setState(() => _recipiente = v),
            ),
            const Divider(),
            Text('Embalagens', style: Theme.of(context).textTheme.titleSmall),
            const Text('Quanto vale 1 caixa, pacote, saco... na unidade base.'),
            for (var n = 0; n < _embalagens.length; n++)
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _embalagens[n].nome,
                    enabled: !_salvando,
                    decoration:
                        const InputDecoration(labelText: 'Embalagem (ex.: cx)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _embalagens[n].qtd,
                    enabled: !_salvando,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Quantidade na base'),
                    validator: (v) => _embalagens[n].nome.text.trim().isEmpty ||
                            (Numero.lerQuantidade(v) ?? 0) > 0
                        ? null
                        : 'Maior que zero.',
                  ),
                ),
              ]),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _salvando
                    ? null
                    : () => setState(() => _embalagens.add(_LinhaEmbalagem())),
                icon: const Icon(Icons.add),
                label: const Text('Adicionar embalagem'),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _salvando ? null : _salvar,
              child: _salvando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_editando ? 'Salvar alterações' : 'Criar item'),
            ),
            if (_editando) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _salvando ? null : _inativar,
                icon: const Icon(Icons.block),
                label: const Text('Tirar de uso'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
