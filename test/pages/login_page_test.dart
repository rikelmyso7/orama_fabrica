import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_de_teste.dart';
import '../support/servidor_falso.dart';

void main() {
  setUpAll(prepararDatas);

  testWidgets('campos vazios mostram os avisos e não chamam a API',
      (tester) async {
    final m = await abrirApp(tester, logado: false);

    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Campo obrigatório'), findsNWidgets(2));
    expect(m.servidor.chamadas('POST', '/auth/login'), isEmpty);
  });

  testWidgets('senha errada mostra a mensagem da API e continua no login',
      (tester) async {
    final m = await abrirApp(tester, logado: false, configurar: (s) {
      s.rota(
          'POST',
          '/auth/login',
          (_) => problema(
              401, 'credenciais_invalidas', 'Login ou senha incorretos.'));
    });

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Login'), 'func1');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Senha'), 'errada');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Login ou senha incorretos.'), findsOneWidget);
    expect(find.text('Orama Fábrica'), findsOneWidget);
    expect(m.deps.auth.logado, isFalse);
  });

  testWidgets('bloqueio por muitas tentativas mostra o aviso do servidor',
      (tester) async {
    await abrirApp(tester, logado: false, configurar: (s) {
      s.rota(
          'POST',
          '/auth/login',
          (_) => problema(429, 'bloqueado',
              'Muitas tentativas erradas. Aguarde alguns minutos e tente de novo.'));
    });

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Login'), 'func1');
    await tester.enterText(find.widgetWithText(TextFormField, 'Senha'), 'x');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Muitas tentativas erradas'), findsOneWidget);
  });

  testWidgets('sem conexão avisa em vez de travar', (tester) async {
    final m = await abrirApp(tester, logado: false);
    m.servidor.offline = true;

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Login'), 'func1');
    await tester.enterText(find.widgetWithText(TextFormField, 'Senha'), 'x');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Sem conexão com o servidor.'), findsOneWidget);
  });

  testWidgets('login certo abre o app e envia o login sem espaços nas pontas',
      (tester) async {
    final m = await abrirApp(tester, logado: false);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Login'), '  func1 ');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Senha'), 'senha-123');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Nova entrada'), findsOneWidget);
    expect(m.servidor.chamadas('POST', '/auth/login').single.corpo,
        {'login': 'func1', 'senha': 'senha-123'});
  });

  testWidgets('o botão do olho mostra e esconde a senha', (tester) async {
    await abrirApp(tester, logado: false);
    TextField campoSenha() => tester.widget<TextField>(find.descendant(
        of: find.widgetWithText(TextFormField, 'Senha'),
        matching: find.byType(TextField)));
    expect(campoSenha().obscureText, isTrue);

    await tester.tap(find.byTooltip('Mostrar senha'));
    await tester.pump();

    expect(campoSenha().obscureText, isFalse);
  });
}
