import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_de_teste.dart';
import '../support/servidor_falso.dart';

/// Responde POST /entradas aceitando tudo, como a API faz com entradas válidas.
void servidorAceita(ServidorFalso s) => s.rota('POST', '/entradas', (r) {
      final itens = (r.corpo['itens'] as List).cast<Map<String, dynamic>>();
      return json({
        'loteEnvioId': 'x',
        'resultados': [
          for (var i = 0; i < itens.length; i++)
            {'id': itens[i]['id'], 'status': 'criado', 'etiqueta': 'R00000${i + 1}', 'qtdBase': itens[i]['quantidade']},
        ],
      });
    });

Future<void> escolherUnidade(WidgetTester tester, String unidade) async {
  await tester.tap(find.byKey(const Key('campo-unidade')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(unidade).last);
  await tester.pumpAndSettle();
}

Future<void> adicionarPeso(WidgetTester tester, String peso) async {
  await tester.enterText(find.byKey(const Key('campo-peso')), peso);
  await tester.tap(find.byKey(const Key('adicionar-peso')));
  await tester.pumpAndSettle();
}

/// Lança um BROWNIE com a quantidade informada e salva.
Future<void> lancarBrownie(WidgetTester tester, String quantidade) async {
  await abrirNovaEntrada(tester);
  await tester.tap(find.text('BROWNIE'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('campo-quantidade')), quantidade);
  await tester.tap(find.text('Adicionar'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Revisar entrada (1)'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Salvar entrada (1)'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(prepararDatas);

  testWidgets('item comum: quantidade, revisar, salvar e a API recebe a linha certa', (tester) async {
    final m = await abrirApp(tester, configurar: servidorAceita);

    await abrirNovaEntrada(tester);
    await tester.tap(find.text('BROWNIE'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo-quantidade')), '12');
    await tester.tap(find.text('Adicionar'));
    await tester.pumpAndSettle();

    expect(find.text('Revisar entrada (1)'), findsOneWidget);
    await tester.tap(find.text('Revisar entrada (1)'));
    await tester.pumpAndSettle();
    expect(find.text('12 un'), findsOneWidget);
    await tester.tap(find.text('Salvar entrada (1)'));
    await tester.pumpAndSettle();

    final enviado = (m.servidor.chamadas('POST', '/entradas').single.corpo['itens'] as List).single as Map;
    expect(enviado['itemId'], 'it-cookie');
    expect(enviado['quantidade'], 12);
    expect(enviado['unidade'], 'un');
    expect(enviado['origem'], 'producao');
    expect(enviado['id'], isNotEmpty);
    expect(find.text('1 registrada'), findsOneWidget);
    expect(find.text('Nova entrada'), findsOneWidget, reason: 'voltou para a tela inicial');
    expect(m.deps.fila.doUsuario('u-func'), isEmpty);
  });

  testWidgets('baldes: lote uma vez e uma lista de pesos vira uma linha por recipiente', (tester) async {
    final m = await abrirApp(tester, configurar: servidorAceita);

    await abrirNovaEntrada(tester);
    await tester.tap(find.text('COCADA'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo-lote')), 'L7');
    await adicionarPeso(tester, '4100');
    await escolherUnidade(tester, 'kg');
    await adicionarPeso(tester, '3,85');

    expect(find.text('4.100 g'), findsOneWidget);
    expect(find.text('3,85 kg'), findsOneWidget);
    await tester.tap(find.text('Adicionar 2 recipientes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revisar entrada (2)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar entrada (2)'));
    await tester.pumpAndSettle();

    final itens = (m.servidor.chamadas('POST', '/entradas').single.corpo['itens'] as List).cast<Map>();
    expect(itens.map((i) => i['quantidade']), [4100, 3.85]);
    expect(itens.map((i) => i['unidade']), ['g', 'kg']);
    expect(itens.every((i) => i['unidades'] == 1 && i['lote'] == 'L7' && i['itemId'] == 'it-balde'), isTrue);
    expect(itens.map((i) => i['id']).toSet(), hasLength(2));
    expect(find.text('2 registradas'), findsOneWidget);
  });

  testWidgets('recipiente sem lote ou sem peso mostra o motivo e não adiciona', (tester) async {
    await abrirApp(tester);
    await abrirNovaEntrada(tester);
    await tester.tap(find.text('COCADA'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Adicionar'));
    await tester.pumpAndSettle();
    expect(find.text('Informe o lote que está na etiqueta.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('campo-lote')), 'L1');
    await tester.tap(find.text('Adicionar'));
    await tester.pumpAndSettle();
    expect(find.text('Adicione o peso de pelo menos um recipiente.'), findsOneWidget);
  });

  testWidgets('peso fora do esperado pede confirmação (erro de unidade)', (tester) async {
    await abrirApp(tester);
    await abrirNovaEntrada(tester);
    await tester.tap(find.text('COCADA'));
    await tester.pumpAndSettle();

    await adicionarPeso(tester, '4');
    expect(find.text('Peso fora do esperado'), findsOneWidget);
    await tester.tap(find.text('Corrigir'));
    await tester.pumpAndSettle();
    expect(find.byType(InputChip), findsNothing);

    await adicionarPeso(tester, '4');
    await tester.tap(find.text('Está certo'));
    await tester.pumpAndSettle();
    expect(find.byType(InputChip), findsOneWidget);
  });

  testWidgets('peso inválido mostra o aviso e os pesos podem ser removidos', (tester) async {
    await abrirApp(tester);
    await abrirNovaEntrada(tester);
    await tester.tap(find.text('COCADA'));
    await tester.pumpAndSettle();

    await adicionarPeso(tester, 'abc');
    expect(find.text('Digite um peso válido, por exemplo 4,1.'), findsOneWidget);

    await adicionarPeso(tester, '4100');
    expect(find.byType(InputChip), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(InputChip), matching: find.byIcon(Icons.clear)));
    await tester.pumpAndSettle();
    expect(find.byType(InputChip), findsNothing);
  });

  testWidgets('quantidade inválida em item comum é recusada na tela', (tester) async {
    await abrirApp(tester);
    await abrirNovaEntrada(tester);
    await tester.tap(find.text('BROWNIE'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('campo-quantidade')), '0');
    await tester.tap(find.text('Adicionar'));
    await tester.pumpAndSettle();

    expect(find.text('Digite uma quantidade válida, maior que zero.'), findsOneWidget);
  });

  testWidgets('item de terceiros entra como compra e aceita a embalagem como unidade', (tester) async {
    final m = await abrirApp(tester, configurar: servidorAceita);
    await abrirNovaEntrada(tester);
    await tester.tap(find.text('CASTANHA GLACEADA'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('campo-quantidade')), '2');
    await escolherUnidade(tester, 'cx');
    await tester.tap(find.text('Adicionar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revisar entrada (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar entrada (1)'));
    await tester.pumpAndSettle();

    final enviado = (m.servidor.chamadas('POST', '/entradas').single.corpo['itens'] as List).single as Map;
    expect((enviado['unidade'], enviado['origem']), ('cx', 'compra'));
  });

  testWidgets('sem internet: salva no aparelho, mostra "aguardando" e envia quando a conexão volta', (tester) async {
    final m = await abrirApp(tester, configurar: servidorAceita);
    m.servidor.offline = true;

    await lancarBrownie(tester, '5');

    expect(find.text('1 aguardando conexão'), findsOneWidget);
    expect(find.text('Aguardando envio'), findsWidgets);
    expect(m.deps.fila.aguardando('u-func'), 1);

    m.servidor.offline = false;
    await tester.tap(find.byIcon(Icons.cloud_upload_outlined));
    await tester.pumpAndSettle();

    expect(m.deps.fila.doUsuario('u-func'), isEmpty);
    expect(m.servidor.chamadas('POST', '/entradas'), hasLength(2), reason: 'a tentativa offline e a que deu certo');
  });

  testWidgets('linha recusada pela API fica visível com o motivo, e dá para descartar', (tester) async {
    final m = await abrirApp(tester, configurar: (s) {
      s.rota('POST', '/entradas', (r) {
        final id = ((r.corpo['itens'] as List).first as Map)['id'];
        return json({'resultados': [{'id': id, 'status': 'recusado', 'erro': 'A data da entrada está no futuro.'}]});
      });
    });

    await lancarBrownie(tester, '5');

    expect(find.text('1 recusada: veja em Hoje'), findsOneWidget);
    expect(find.text('A data da entrada está no futuro.'), findsOneWidget);

    await tester.tap(find.byTooltip('Descartar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar').last);
    await tester.pumpAndSettle();
    expect(m.deps.fila.doUsuario('u-func'), isEmpty);
  });

  testWidgets('sair com linhas não salvas pergunta antes de descartar', (tester) async {
    await abrirApp(tester);
    await abrirNovaEntrada(tester);
    await tester.tap(find.text('BROWNIE'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('campo-quantidade')), '5');
    await tester.tap(find.text('Adicionar'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Descartar entrada?'), findsOneWidget);

    await tester.tap(find.text('Continuar editando'));
    await tester.pumpAndSettle();
    expect(find.text('Revisar entrada (1)'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Descartar'));
    await tester.pumpAndSettle();
    expect(find.text('Revisar entrada (1)'), findsNothing);
    expect(find.text('Nova entrada'), findsOneWidget);
  });

  testWidgets('a busca filtra por texto sem acento e a categoria filtra os itens', (tester) async {
    await abrirApp(tester);
    await abrirNovaEntrada(tester);
    expect(find.text('COCADA'), findsOneWidget);
    expect(find.text('BROWNIE'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'castanha');
    await tester.pumpAndSettle();
    expect(find.text('CASTANHA GLACEADA'), findsOneWidget);
    expect(find.text('COCADA'), findsNothing);

    await tester.enterText(find.byType(TextField).first, '');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Baldes'));
    await tester.pumpAndSettle();
    expect(find.text('COCADA'), findsOneWidget);
    expect(find.text('BROWNIE'), findsNothing);
  });

  testWidgets('sem catálogo mostra o motivo e um botão para tentar de novo', (tester) async {
    await abrirApp(tester, configurar: (s) {
      s.rota('GET', '/catalogo', (_) => problema(500, 'erro_interno', 'Erro interno. Tente novamente.'));
    });

    await abrirNovaEntrada(tester);

    expect(find.text('Erro interno. Tente novamente.'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);
  });
}
