import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orama_fabrica2/data/entrada_pendente.dart';

import '../support/app_de_teste.dart';
import '../support/servidor_falso.dart';

EntradaPendente pendente(String id, String nome, String quantidade) =>
    EntradaPendente(
      id: id,
      usuarioId: 'u-func',
      itemId: 'it-cookie',
      itemNome: nome,
      quantidade: quantidade,
      unidade: 'un',
      origem: 'producao',
      ocorridoEm: DateTime.now(),
    );

String dia(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

void main() {
  setUpAll(prepararDatas);

  Future<void> abrirMenu(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Opções').first);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'mostra os lançamentos do dia com quantidade, local, lote e etiqueta',
      (tester) async {
    await abrirApp(tester, configurar: (s) {
      s.responder('GET', '/movimentos', [
        movimentoJson(
            item: 'COCADA',
            quantidade: 4100,
            unidade: 'g',
            lote: 'L7',
            etiqueta: 'R000001'),
        movimentoJson(id: 'm2', item: 'BROWNIE', quantidade: 12),
      ]);
    });

    expect(find.text('COCADA'), findsOneWidget);
    expect(find.textContaining('4.100 g'), findsOneWidget);
    expect(find.textContaining('Lote L7'), findsOneWidget);
    expect(find.textContaining('R000001'), findsOneWidget);
    expect(find.textContaining('Câmara frigorífica'), findsNWidgets(2));
  });

  testWidgets(
      'lançamento importado com dúvida mostra o alerta, o motivo e o texto original',
      (tester) async {
    await abrirApp(tester, configurar: (s) {
      s.responder('GET', '/movimentos', [
        movimentoJson(id: 'm-ok', item: 'BROWNIE'),
        movimentoJson(
          id: 'm-duvida',
          tipo: 'saida',
          item: 'DEXTROSE',
          quantidade: 4902,
          unidade: 'g',
          textoOriginal: 'Dextrose | 4902 Kg',
          revisar: 'kg sem decimal (>=1000) - dividido por 1000',
        ),
      ]);
    });

    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget,
        reason: 'só o lançamento duvidoso tem alerta');

    await tester.tap(find.byIcon(Icons.warning_amber_rounded));
    await tester.pumpAndSettle();

    expect(find.textContaining('dividido por 1000'), findsOneWidget);
    expect(find.textContaining('Dextrose | 4902 Kg'), findsOneWidget);
  });

  testWidgets('a consulta do dia pede só aquele dia à API', (tester) async {
    final m = await abrirApp(tester);

    final q =
        m.servidor.chamadas('GET', '/movimentos').first.uri.queryParameters;
    expect(q['de'], dia(DateTime.now()));
    expect(q['ate'], dia(DateTime.now()));
  });

  testWidgets(
      'dia anterior consulta aquele dia, e em "hoje" não há dia seguinte',
      (tester) async {
    final m = await abrirApp(tester);
    IconButton seguinte() => tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.arrow_forward));
    expect(seguinte().onPressed, isNull);

    await tester.tap(find.byTooltip('Dia anterior'));
    await tester.pumpAndSettle();

    final ontem = DateTime.now().subtract(const Duration(days: 1));
    expect(
        m.servidor
            .chamadas('GET', '/movimentos')
            .last
            .uri
            .queryParameters['de'],
        dia(ontem));
    expect(seguinte().onPressed, isNotNull);
  });

  testWidgets('sem lançamentos mostra o aviso', (tester) async {
    await abrirApp(tester);

    expect(find.text('Nenhum lançamento neste dia.'), findsOneWidget);
  });

  testWidgets(
      'sem internet avisa que o histórico do servidor não foi carregado',
      (tester) async {
    final m = await abrirApp(tester);
    m.servidor.offline = true;

    await tester.drag(find.byType(ListView).first, const Offset(0, 900));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.textContaining('O histórico do servidor não foi carregado.'),
        findsOneWidget);
  });

  testWidgets('estorno: pede motivo e senha, manda para a API e recarrega',
      (tester) async {
    var carregamentos = 0;
    final m = await abrirApp(tester, configurar: (s) {
      s.rota('GET', '/movimentos', (_) {
        carregamentos++;
        return json(
            [movimentoJson(id: 'm-1', item: 'BROWNIE', quantidade: 12)]);
      });
      s.rota(
          'POST', '/movimentos/m-1/estorno', (_) => json({'status': 'criado'}));
    });

    await abrirMenu(tester);
    await tester.tap(find.text('Estornar'));
    await tester.pumpAndSettle();
    expect(find.text('Estornar lançamento'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Estornar'));
    await tester.pumpAndSettle();
    expect(find.text('Informe o motivo'), findsOneWidget);
    expect(find.text('Informe a senha'), findsOneWidget);
    expect(m.servidor.chamadas('POST', '/movimentos/m-1/estorno'), isEmpty);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Motivo'), 'lançado errado');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Senha de administrador'),
        'autoriza-xyz');
    await tester.tap(find.widgetWithText(FilledButton, 'Estornar'));
    await tester.pumpAndSettle();

    final corpo = m.servidor
        .chamadas('POST', '/movimentos/m-1/estorno')
        .single
        .corpo as Map;
    expect(corpo['motivo'], 'lançado errado');
    expect(corpo['senha'], 'autoriza-xyz');
    expect(corpo['novoId'], isNotEmpty);
    expect(find.text('Lançamento estornado.'), findsOneWidget);
    expect(carregamentos, 2,
        reason: 'carregou ao abrir e recarregou depois do estorno');
  });

  testWidgets('senha de administrador errada mostra a mensagem da API',
      (tester) async {
    await abrirApp(tester, configurar: (s) {
      s.responder('GET', '/movimentos', [movimentoJson(id: 'm-1')]);
      s.rota(
          'POST',
          '/movimentos/m-1/estorno',
          (_) => problema(
              403, 'senha_invalida', 'Senha de administrador incorreta.'));
    });

    await abrirMenu(tester);
    await tester.tap(find.text('Estornar'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Motivo'), 'erro');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Senha de administrador'), 'errada');
    await tester.tap(find.widgetWithText(FilledButton, 'Estornar'));
    await tester.pumpAndSettle();

    expect(find.text('Senha de administrador incorreta.'), findsOneWidget);
  });

  testWidgets('estorno exige conexão: sem internet avisa que não foi feito',
      (tester) async {
    final m = await abrirApp(tester,
        configurar: (s) =>
            s.responder('GET', '/movimentos', [movimentoJson(id: 'm-1')]));

    await abrirMenu(tester);
    await tester.tap(find.text('Estornar'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Motivo'), 'erro');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Senha de administrador'), 'x');
    m.servidor.offline = true;
    await tester.tap(find.widgetWithText(FilledButton, 'Estornar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('O estorno não foi feito.'), findsOneWidget);
  });

  testWidgets('cancelar o estorno não chama a API', (tester) async {
    final m = await abrirApp(tester,
        configurar: (s) =>
            s.responder('GET', '/movimentos', [movimentoJson(id: 'm-1')]));

    await abrirMenu(tester);
    await tester.tap(find.text('Estornar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(m.servidor.requisicoes.where((r) => r.caminho.contains('estorno')),
        isEmpty);
  });

  testWidgets('lançamento já estornado, ajuste e estorno não oferecem estornar',
      (tester) async {
    await abrirApp(tester, configurar: (s) {
      s.responder('GET', '/movimentos', [
        movimentoJson(id: 'a', item: 'JÁ ESTORNADO', estornado: true),
        movimentoJson(
            id: 'b',
            item: 'AJUSTE',
            tipo: 'ajuste',
            quantidade: -250,
            motivo: 'quebra',
            autorizadoPor: 'Administrador'),
        movimentoJson(
            id: 'c', item: 'O ESTORNO', tipo: 'saida', estornaId: 'a'),
      ]);
    });

    expect(find.byTooltip('Opções'), findsNothing);
    expect(find.textContaining('Estornado'), findsOneWidget);
    expect(find.textContaining('Motivo: quebra'), findsOneWidget);
    expect(find.textContaining('Autorizado por Administrador'), findsOneWidget);
  });

  testWidgets('perfil só de leitura vê o histórico mas não lança nem estorna',
      (tester) async {
    await abrirApp(tester, usuario: {...usuarioFabricaJson, 'papel': 'leitura'},
        configurar: (s) {
      s.responder('GET', '/movimentos', [movimentoJson(id: 'm-1')]);
    });

    expect(find.text('BROWNIE'), findsOneWidget);
    expect(find.text('Nova entrada'), findsNothing);
    expect(find.byTooltip('Opções'), findsNothing);
  });

  testWidgets(
      'entradas aguardando envio aparecem acima do histórico, e descartar pede confirmação',
      (tester) async {
    final m = await abrirApp(tester);
    m.servidor.offline = true;
    await m.deps.fila.adicionar([pendente('p1', 'BROWNIE', '7')]);
    await tester.pumpAndSettle();

    expect(find.text('Aguardando envio'), findsWidgets);
    expect(find.textContaining('BROWNIE · 7 un'), findsOneWidget);

    await tester.tap(find.byTooltip('Descartar'));
    await tester.pumpAndSettle();
    expect(find.text('Descartar entrada?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(m.deps.fila.doUsuario('u-func'), hasLength(1));
  });

  testWidgets('sair com entradas não confirmadas avisa que ficam guardadas',
      (tester) async {
    final m = await abrirApp(tester);
    m.servidor.offline = true;
    await m.deps.fila.adicionar([pendente('p1', 'BROWNIE', '7')]);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sair'));
    await tester.pumpAndSettle();

    expect(find.text('Sair mesmo assim?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Sair'));
    await tester.pumpAndSettle();
    expect(m.deps.auth.logado, isFalse);
    expect(m.deps.fila.doUsuario('u-func'), hasLength(1),
        reason: 'a entrada continua guardada');
  });
}
