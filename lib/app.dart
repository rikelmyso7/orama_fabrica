import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'api/api_client.dart';
import 'api/orama_api.dart';
import 'auth/auth_store.dart';
import 'data/catalogo_store.dart';
import 'data/fila_entradas.dart';
import 'data/fila_operacoes.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'pages/splash_page.dart';
import 'storage/storage.dart';
import 'update/atualizacao.dart';

const corPrincipal = Color(0xff60C03D);

/// Em tela larga (Windows) o app fica numa coluna central em vez de esticar a lista por toda a janela.
const larguraMaximaDoApp = 840.0;

/// Tudo que o app usa, montado em um lugar só. Os testes montam o mesmo conjunto com servidor falso.
class AppDependencias {
  AppDependencias({
    required this.client,
    required this.api,
    required this.auth,
    required this.catalogo,
    required this.fila,
    required this.filaOperacoes,
    this.atualizacao,
  });

  final ApiClient client;
  final OramaApi api;
  final AuthStore auth;
  final CatalogoStore catalogo;
  final FilaEntradas fila;
  final FilaOperacoes filaOperacoes;

  /// Verificação de versão nova pelos releases do GitHub. Nulo desliga a consulta (testes, web).
  final ServicoAtualizacao? atualizacao;

  factory AppDependencias.criar({
    required String baseUrl,
    required KeyValueStore store,
    required SecureStore secure,
    http.Client? httpClient,
    ServicoAtualizacao? atualizacao,
  }) {
    final client = ApiClient(baseUrl: baseUrl, client: httpClient);
    final api = OramaApi(client);
    return AppDependencias(
      client: client,
      api: api,
      auth: AuthStore(api, client, secure),
      catalogo: CatalogoStore(api, store),
      fila: FilaEntradas(api, store),
      filaOperacoes: FilaOperacoes(api, store),
      atualizacao: atualizacao,
    );
  }
}

ThemeData temaDoApp() => ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: corPrincipal),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(backgroundColor: corPrincipal, foregroundColor: Colors.white),
    );

class OramaApp extends StatelessWidget {
  const OramaApp({super.key, required this.deps, this.problemaDeConfiguracao});

  final AppDependencias deps;

  /// Se o endereço da API estiver errado, o app mostra o motivo em vez de falhar sem explicar.
  final String? problemaDeConfiguracao;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<OramaApi>.value(value: deps.api),
        ChangeNotifierProvider<AuthStore>.value(value: deps.auth),
        ChangeNotifierProvider<CatalogoStore>.value(value: deps.catalogo),
        ChangeNotifierProvider<FilaEntradas>.value(value: deps.fila),
        ChangeNotifierProvider<FilaOperacoes>.value(value: deps.filaOperacoes),
        Provider<ServicoAtualizacao?>.value(value: deps.atualizacao),
      ],
      child: MaterialApp(
        title: 'Orama Fábrica',
        debugShowCheckedModeBanner: false,
        theme: temaDoApp(),
        builder: (context, child) => Center(
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: larguraMaximaDoApp), child: child),
        ),
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: problemaDeConfiguracao != null
            ? PaginaDeConfiguracao(problema: problemaDeConfiguracao!)
            : const AuthGate(),
      ),
    );
  }
}

/// Decide a tela inicial pela sessão: carregando, login ou o app. Se o servidor recusar o token
/// em qualquer chamada, a sessão cai e o app volta para o login sozinho.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthStore>();
    if (auth.estado == EstadoAuth.carregando) {
      WidgetsBinding.instance.addPostFrameCallback((_) => auth.restaurar());
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    return switch (auth.estado) {
      EstadoAuth.carregando => const SplashPage(),
      EstadoAuth.deslogado => const LoginPage(),
      EstadoAuth.logado => (auth.usuario?.podeConsultar ?? false) ? const HomePage() : const SemAcessoPage(),
    };
  }
}

class SemAcessoPage extends StatelessWidget {
  const SemAcessoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48),
              const SizedBox(height: 12),
              const Text('Seu perfil não tem acesso ao app da fábrica.', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: () => context.read<AuthStore>().sair(), child: const Text('Sair')),
            ],
          ),
        ),
      ),
    );
  }
}

class PaginaDeConfiguracao extends StatelessWidget {
  const PaginaDeConfiguracao({super.key, required this.problema});

  final String problema;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(problema, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
