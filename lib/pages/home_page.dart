import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_store.dart';
import '../data/catalogo_store.dart';
import '../data/fila_entradas.dart';
import '../update/atualizacao.dart';
import 'atualizacao_dialog.dart';
import 'estoque_page.dart';
import 'historico_page.dart';

/// Tela principal: hoje (histórico e entradas aguardando envio) e estoque. Também mantém o app
/// sincronizado: ao abrir, ao voltar para o app e a cada minuto, envia o que ficou na fila.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  static const _intervalo = Duration(seconds: 60);

  int _aba = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sincronizar();
      _verificarAtualizacao();
    });
    _timer = Timer.periodic(_intervalo, (_) => _sincronizar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _sincronizar();
  }

  /// Uma vez por abertura do app: se houver versão nova nos releases, oferece (opcional).
  void _verificarAtualizacao() {
    if (!mounted) return;
    final servico = context.read<ServicoAtualizacao?>();
    if (servico != null) unawaited(oferecerAtualizacao(context, servico));
  }

  Future<ResultadoSync?> _sincronizar() async {
    if (!mounted) return null;
    final usuario = context.read<AuthStore>().usuario;
    if (usuario == null) return null;
    final catalogo = context.read<CatalogoStore>();
    final fila = context.read<FilaEntradas>();
    if (catalogo.precisaAtualizar) unawaited(catalogo.atualizar());
    if (usuario.podeLancar && fila.aguardando(usuario.id) > 0) {
      return fila.enviar(usuario.id);
    }
    return null;
  }

  Future<void> _sair() async {
    final auth = context.read<AuthStore>();
    final usuario = auth.usuario;
    final fila = context.read<FilaEntradas>();
    final pendentes = usuario == null ? 0 : fila.doUsuario(usuario.id).length;
    if (pendentes > 0) {
      final sair = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Sair mesmo assim?'),
          content: Text('Há $pendentes ${pendentes == 1 ? 'entrada' : 'entradas'} que ainda não '
              'foram confirmadas pelo servidor. Elas ficam guardadas no aparelho e são enviadas '
              'quando você entrar de novo.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sair')),
          ],
        ),
      );
      if (sair != true) return;
    }
    await auth.sair();
  }

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<AuthStore>().usuario;
    return Scaffold(
      appBar: AppBar(
        title: Text(_aba == 0 ? 'Hoje' : 'Estoque'),
        actions: [
          const _IndicadorDeEnvio(),
          PopupMenuButton<String>(
            tooltip: 'Menu',
            onSelected: (v) {
              if (v == 'sair') _sair();
            },
            itemBuilder: (_) => [
              PopupMenuItem(enabled: false, child: Text(usuario?.nome ?? '')),
              const PopupMenuItem(value: 'sair', child: Text('Sair')),
            ],
          ),
        ],
      ),
      body: IndexedStack(index: _aba, children: const [HistoricoPage(), EstoquePage()]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _aba,
        onDestinationSelected: (i) => setState(() => _aba = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today), label: 'Hoje'),
          NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Estoque'),
        ],
      ),
    );
  }
}

/// Mostra se há entradas esperando envio ou recusadas, e deixa tocar para enviar agora.
class _IndicadorDeEnvio extends StatelessWidget {
  const _IndicadorDeEnvio();

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<AuthStore>().usuario;
    final fila = context.watch<FilaEntradas>();
    if (usuario == null) return const SizedBox.shrink();
    if (fila.enviando) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
      );
    }
    final aguardando = fila.aguardando(usuario.id);
    final recusadas = fila.recusadas(usuario.id);
    if (aguardando == 0 && recusadas == 0) return const SizedBox.shrink();
    return IconButton(
      tooltip: recusadas > 0 ? '$recusadas recusadas, $aguardando aguardando envio' : '$aguardando aguardando envio',
      onPressed: aguardando == 0 ? null : () => fila.enviar(usuario.id),
      icon: Badge(
        label: Text('${aguardando + recusadas}'),
        backgroundColor: recusadas > 0 ? Colors.red : Colors.orange,
        child: Icon(recusadas > 0 ? Icons.warning_amber : Icons.cloud_upload_outlined),
      ),
    );
  }
}
