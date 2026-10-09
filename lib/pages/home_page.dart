import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_store.dart';
import '../data/catalogo_store.dart';
import '../data/fila_entradas.dart';
import '../data/fila_operacoes.dart';
import '../update/atualizacao.dart';
import 'atualizacao_dialog.dart';
import 'catalogo_admin_page.dart';
import 'estoque_page.dart';
import 'formulas_page.dart';
import 'historico_page.dart';
import 'movimentacoes_page.dart';
import 'nova_producao_page.dart';

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
    final filaOperacoes = context.read<FilaOperacoes>();
    if (catalogo.precisaAtualizar) unawaited(catalogo.atualizar());
    if (usuario.podeLancar && fila.aguardando(usuario.id) > 0) {
      final resultado = await fila.enviar(usuario.id);
      if (filaOperacoes.aguardando(usuario.id) > 0) {
        await filaOperacoes.enviar(usuario.id);
      }
      return resultado;
    }
    if (usuario.podeLancar && filaOperacoes.aguardando(usuario.id) > 0) {
      return filaOperacoes.enviar(usuario.id);
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
          content: Text(
              'Há $pendentes ${pendentes == 1 ? 'entrada' : 'entradas'} que ainda não '
              'foram confirmadas pelo servidor. Elas ficam guardadas no aparelho e são enviadas '
              'quando você entrar de novo.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Sair')),
          ],
        ),
      );
      if (sair != true) return;
    }
    await auth.sair();
  }

  static const _titulos = ['Hoje', 'Estoque', 'Movimentações'];
  static const _abaProducao = 3;

  void _abrir(Widget pagina) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => pagina));

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<AuthStore>().usuario;
    final podeLancar = usuario?.podeLancar ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(_titulos[_aba]),
        actions: const [_IndicadorDeEnvio()],
      ),
      drawer: _MenuLateral(
        usuarioNome: usuario?.nome ?? '',
        ehAdmin: usuario?.ehAdmin ?? false,
        abrirItens: () => _abrir(const CatalogoAdminPage()),
        abrirFormulas: () => _abrir(const FormulasPage()),
        sair: _sair,
      ),
      body: IndexedStack(
        index: _aba,
        children: [
          const HistoricoPage(),
          const EstoquePage(),
          MovimentacoesPage(ativa: _aba == 2)
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _aba,
        // "Produção" abre uma tela própria em vez de trocar de aba
        onDestinationSelected: (i) => i == _abaProducao
            ? _abrir(const NovaProducaoPage())
            : setState(() => _aba = i),
        destinations: [
          const NavigationDestination(
              icon: Icon(Icons.today_outlined),
              selectedIcon: Icon(Icons.today),
              label: 'Hoje'),
          const NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2),
              label: 'Estoque'),
          const NavigationDestination(
              icon: Icon(Icons.swap_vert_outlined),
              selectedIcon: Icon(Icons.swap_vert),
              label: 'Movimentações'),
          if (podeLancar)
            const NavigationDestination(
                icon: Icon(Icons.precision_manufacturing_outlined),
                label: 'Nova produção'),
        ],
      ),
    );
  }
}

class _MenuLateral extends StatelessWidget {
  const _MenuLateral({
    required this.usuarioNome,
    required this.ehAdmin,
    required this.abrirItens,
    required this.abrirFormulas,
    required this.sair,
  });

  final String usuarioNome;
  final bool ehAdmin;
  final VoidCallback abrirItens;
  final VoidCallback abrirFormulas;
  final VoidCallback sair;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width / 1.4,
      child: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              padding: const EdgeInsets.only(top: 20),
              width: double.infinity,
              height: 100,
              decoration: const BoxDecoration(color: Color(0xff60C03D)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    color: Colors.white,
                    iconSize: 26,
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      usuarioNome.isEmpty ? 'Fábrica' : usuarioNome,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 26),
                    ),
                  ),
                ],
              ),
            ),
            if (ehAdmin) ...[
              _ItemMenuLateral(
                label: 'Itens',
                icon: Icons.inventory_2_outlined,
                onTap: () => _abrir(context, abrirItens),
              ),
              _ItemMenuLateral(
                label: 'Fórmulas',
                icon: Icons.receipt_long_outlined,
                onTap: () => _abrir(context, abrirFormulas),
              ),
            ],
            _ItemMenuLateral(
              label: 'Tela Inicial',
              icon: Icons.home_outlined,
              onTap: () => Navigator.pop(context),
            ),
            _ItemMenuLateral(
              label: 'Sair',
              icon: Icons.logout,
              onTap: () => _abrir(context, sair),
            ),
          ],
        ),
      ),
    );
  }

  void _abrir(BuildContext context, VoidCallback acao) {
    Navigator.pop(context);
    acao();
  }
}

class _ItemMenuLateral extends StatelessWidget {
  const _ItemMenuLateral(
      {required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          title: Align(
            alignment: Alignment.bottomLeft,
            child: Row(
              children: [
                Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 18)),
                const SizedBox(width: 5),
                Icon(icon),
              ],
            ),
          ),
          onTap: onTap,
        ),
        const Divider(),
      ],
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
    final filaOperacoes = context.watch<FilaOperacoes>();
    if (usuario == null) return const SizedBox.shrink();
    if (fila.enviando || filaOperacoes.enviando) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
            width: 20,
            height: 20,
            child:
                CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
      );
    }
    final aguardando =
        fila.aguardando(usuario.id) + filaOperacoes.aguardando(usuario.id);
    final recusadas =
        fila.recusadas(usuario.id) + filaOperacoes.recusadas(usuario.id);
    if (aguardando == 0 && recusadas == 0) return const SizedBox.shrink();
    return IconButton(
      tooltip: recusadas > 0
          ? '$recusadas recusadas, $aguardando aguardando envio'
          : '$aguardando aguardando envio',
      onPressed: aguardando == 0
          ? null
          : () async {
              await fila.enviar(usuario.id);
              await filaOperacoes.enviar(usuario.id);
            },
      icon: Badge(
        label: Text('${aguardando + recusadas}'),
        backgroundColor: recusadas > 0 ? Colors.red : Colors.orange,
        child: Icon(
            recusadas > 0 ? Icons.warning_amber : Icons.cloud_upload_outlined),
      ),
    );
  }
}
