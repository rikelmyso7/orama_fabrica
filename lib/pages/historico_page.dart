import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../api/api_client.dart';
import '../api/models.dart';
import '../api/orama_api.dart';
import '../auth/auth_store.dart';
import '../data/entrada_pendente.dart';
import '../data/fila_entradas.dart';
import '../util/numero.dart';
import '../widgets/alerta_duvida.dart';
import 'estorno_dialog.dart';
import 'nova_entrada_page.dart';

/// O que foi lançado em um dia: primeiro o que ainda aguarda envio (ou foi recusado), depois o que
/// o servidor registrou, com a opção de estornar.
class HistoricoPage extends StatefulWidget {
  const HistoricoPage({super.key});

  @override
  State<HistoricoPage> createState() => _HistoricoPageState();
}

class _HistoricoPageState extends State<HistoricoPage> {
  late DateTime _dia;
  List<Movimento> _movimentos = const [];
  bool _carregando = false;
  String? _aviso;

  static DateTime _hoje() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    _dia = _hoje();
    WidgetsBinding.instance.addPostFrameCallback((_) => _carregar());
  }

  Future<void> _carregar() async {
    final api = context.read<OramaApi>();
    setState(() => _carregando = true);
    try {
      final lista = await api.movimentos(de: _dia, ate: _dia);
      if (!mounted) return;
      setState(() {
        _movimentos = lista;
        _aviso = null;
      });
    } on SemConexaoException catch (e) {
      if (mounted) setState(() => _aviso = '${e.mensagem} O histórico do servidor não foi carregado.');
    } on ApiException catch (e) {
      if (mounted) setState(() => _aviso = e.mensagem);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _mudarDia(int dias) {
    setState(() => _dia = _dia.add(Duration(days: dias)));
    _carregar();
  }

  void _mostrar(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _novaEntrada() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const NovaEntradaPage()));
    if (mounted) _carregar();
  }

  Future<void> _estornar(Movimento m) async {
    final dados = await showDialog<EstornoDados>(
      context: context,
      builder: (_) => EstornoDialog(descricao: '${m.item}: ${Numero.formatar(m.quantidade, m.unidade)}'),
    );
    if (dados == null || !mounted) return;
    final api = context.read<OramaApi>();
    try {
      await api.estornar(
        movimentoId: m.id,
        novoId: const Uuid().v4(),
        motivo: dados.motivo,
        senha: dados.senha,
      );
      if (!mounted) return;
      _mostrar('Lançamento estornado.');
      await _carregar();
    } on ApiException catch (e) {
      if (mounted) _mostrar(e.mensagem);
    } on SemConexaoException catch (e) {
      if (mounted) _mostrar('${e.mensagem} O estorno não foi feito.');
    }
  }

  Future<void> _descartar(EntradaPendente e) async {
    final fila = context.read<FilaEntradas>();
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Descartar entrada?'),
        content:
            Text('${e.itemNome}: ${e.descricao}. Ela ainda não foi registrada no servidor e será apagada do aparelho.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Descartar')),
        ],
      ),
    );
    if (confirmar == true) await fila.descartar(e.id);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    final usuario = auth.usuario;
    final fila = context.watch<FilaEntradas>();
    final pendentes = usuario == null ? const <EntradaPendente>[] : fila.doUsuario(usuario.id);
    final ehHoje = _dia == _hoje();
    final cabecalho = ehHoje ? 'Hoje' : DateFormat("EEEE, dd/MM/yyyy", 'pt_BR').format(_dia);

    return Scaffold(
      floatingActionButton: auth.podeLancar
          ? FloatingActionButton.extended(
              onPressed: _novaEntrada,
              icon: const Icon(Icons.add),
              label: const Text('Nova entrada'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _carregar,
        child: ListView(
          // sempre rolável: sem isso, com a lista curta ou vazia, puxar para atualizar não funciona
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Dia anterior',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _mudarDia(-1),
                ),
                Expanded(
                  child: Text(cabecalho, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
                ),
                IconButton(
                  tooltip: 'Dia seguinte',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: ehHoje ? null : () => _mudarDia(1),
                ),
              ],
            ),
            if (_carregando) const LinearProgressIndicator(),
            if (_aviso != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Text(_aviso!, style: TextStyle(color: Colors.red.shade800)),
              ),
            if (ehHoje && pendentes.isNotEmpty) ...[
              const _Secao('Aguardando envio'),
              for (final e in pendentes) _PendenteTile(entrada: e, aoDescartar: () => _descartar(e)),
            ],
            const _Secao('Registrado'),
            if (_movimentos.isEmpty && !_carregando)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('Nenhum lançamento neste dia.')),
              ),
            for (final m in _movimentos)
              _MovimentoTile(
                movimento: m,
                aoEstornar: (auth.podeLancar && m.podeEstornar) ? () => _estornar(m) : null,
              ),
          ],
        ),
      ),
    );
  }
}

class _Secao extends StatelessWidget {
  const _Secao(this.titulo);

  final String titulo;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(titulo, style: Theme.of(context).textTheme.labelLarge),
      );
}

class _PendenteTile extends StatelessWidget {
  const _PendenteTile({required this.entrada, required this.aoDescartar});

  final EntradaPendente entrada;
  final VoidCallback aoDescartar;

  @override
  Widget build(BuildContext context) {
    final recusada = entrada.erro != null;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: recusada ? Colors.red.shade50 : Colors.orange.shade50,
      child: ListTile(
        leading: Icon(recusada ? Icons.error_outline : Icons.schedule, color: recusada ? Colors.red : Colors.orange),
        title: Text('${entrada.itemNome} · ${entrada.descricao}'),
        subtitle: Text(recusada ? entrada.erro! : 'Aguardando envio'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (recusada)
              IconButton(
                tooltip: 'Tentar de novo',
                icon: const Icon(Icons.refresh),
                onPressed: () => context.read<FilaEntradas>().tentarNovamente(entrada.id),
              ),
            IconButton(tooltip: 'Descartar', icon: const Icon(Icons.delete_outline), onPressed: aoDescartar),
          ],
        ),
      ),
    );
  }
}

class _MovimentoTile extends StatelessWidget {
  const _MovimentoTile({required this.movimento, required this.aoEstornar});

  final Movimento movimento;
  final VoidCallback? aoEstornar;

  @override
  Widget build(BuildContext context) {
    final m = movimento;
    final (icone, cor) = switch (m.tipo) {
      'entrada' => (Icons.south_west, Colors.green),
      'saida' => (Icons.north_east, Colors.red),
      _ => (Icons.tune, Colors.blueGrey),
    };
    final hora = DateFormat('HH:mm').format(m.ocorridoEm);
    final detalhes = [
      if (m.lote != null) 'Lote ${m.lote}',
      if (m.etiqueta != null) m.etiqueta!,
      if (m.usuario != null) m.usuario!,
      if (m.motivo != null) 'Motivo: ${m.motivo}',
      if (m.autorizadoPor != null) 'Autorizado por ${m.autorizadoPor}',
    ].join(' · ');
    final riscado = m.estornado ? const TextStyle(decoration: TextDecoration.lineThrough) : null;

    return ListTile(
      leading: Icon(icone, color: cor),
      title: Text(m.variante == null ? m.item : '${m.item} · ${m.variante}', style: riscado),
      subtitle: Text(
        '${Numero.formatar(m.quantidade, m.unidade)} · $hora · ${m.local}'
        '${detalhes.isEmpty ? '' : '\n$detalhes'}'
        '${m.estornado ? '\nEstornado' : ''}',
      ),
      isThreeLine: detalhes.isNotEmpty || m.estornado,
      trailing: !m.temDuvida && aoEstornar == null
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (m.temDuvida)
                  AlertaDuvida(
                    titulo: m.variante == null ? m.item : '${m.item} · ${m.variante}',
                    motivos: [m.revisar!.trim()],
                    textoOriginal: m.textoOriginal,
                  ),
                if (aoEstornar != null)
                  PopupMenuButton<String>(
                    tooltip: 'Opções',
                    onSelected: (_) => aoEstornar!(),
                    itemBuilder: (_) => const [PopupMenuItem(value: 'estornar', child: Text('Estornar'))],
                  ),
              ],
            ),
    );
  }
}
