import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orama_fabrica2/app.dart';

import 'support/app_de_teste.dart';
import 'support/servidor_falso.dart';

void main() {
  setUpAll(prepararDatas);

  testWidgets('sem sessão salva o app abre no login', (tester) async {
    await abrirApp(tester, logado: false);

    expect(find.text('Orama Fábrica'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets('com sessão salva o app abre direto na tela inicial, sem pedir login', (tester) async {
    final primeiro = montar();
    primeiro.servidor.responder('POST', '/auth/login', loginJson());
    await primeiro.deps.auth.entrar('func1', 'senha-123');

    final m = await abrirApp(tester, logado: false, montagem: montar(secure: primeiro.secure));

    expect(find.text('Nova entrada'), findsOneWidget);
    expect(m.servidor.chamadas('POST', '/auth/login'), isEmpty);
  });

  testWidgets('em tela larga (Windows) o conteúdo fica numa coluna de leitura, não esticado', (tester) async {
    await abrirApp(tester);
    tester.view.physicalSize = const Size(1920, 1000);
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(Scaffold).first).width, lessThanOrEqualTo(larguraMaximaDoApp));
  });

  testWidgets('endereço da API errado mostra o motivo em vez de falhar sem explicar', (tester) async {
    final m = montar();
    await tester.pumpWidget(OramaApp(deps: m.deps, problemaDeConfiguracao: 'O endereço da API não foi configurado.'));

    expect(find.text('O endereço da API não foi configurado.'), findsOneWidget);
    expect(m.servidor.requisicoes, isEmpty);
  });

  testWidgets('perfil sem acesso (loja) não vê o estoque da fábrica e pode sair', (tester) async {
    final m = await abrirApp(tester, usuario: {...usuarioFabricaJson, 'papel': 'loja'});

    expect(find.text('Seu perfil não tem acesso ao app da fábrica.'), findsOneWidget);
    expect(m.servidor.chamadas('GET', '/movimentos'), isEmpty);

    await tester.tap(find.text('Sair'));
    await tester.pumpAndSettle();
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets('se o servidor recusar o token (401), o app volta para o login e apaga a sessão', (tester) async {
    final m = await abrirApp(tester, configurar: (s) {
      s.rota('GET', '/saldo', (_) => problema(401, 'nao_autorizado', 'x'));
    });

    expect(find.text('Entrar'), findsOneWidget);
    expect(m.deps.auth.logado, isFalse);
    expect(m.secure.dados, isEmpty);
  });

  testWidgets('o app abre sem erro de layout em tela pequena', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final m = montar();
    m.servidor.responder('GET', '/movimentos', <Object?>[]);
    m.servidor.responder('GET', '/saldo', <Object?>[]);
    m.servidor.responder('GET', '/catalogo', catalogoJson());
    m.servidor.responder('POST', '/auth/login', loginJson());
    await m.deps.auth.entrar('func1', 'senha-123');

    await tester.pumpWidget(OramaApp(deps: m.deps));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Nova entrada'), findsOneWidget);
  });
}
