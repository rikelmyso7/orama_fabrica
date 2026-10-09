import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_de_teste.dart';

Future<void> irParaMovimentacoes(WidgetTester tester) async {
  await tester.tap(find.text('Movimentações').last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(prepararDatas);

  testWidgets(
      'aba de movimentações carrega últimos lançamentos com busca e detalhes',
      (tester) async {
    await abrirApp(tester, configurar: (s) {
      s.responder('GET', '/movimentos', [
        movimentoJson(
          id: 'm-rastreio',
          item: 'COCADA',
          quantidade: 4100,
          unidade: 'g',
          lote: '26100801',
          etiqueta: 'R000010',
          operationId: 'op-1',
          responsavel: 'Maria',
        ),
        movimentoJson(id: 'm-brownie', item: 'BROWNIE', quantidade: 12),
      ]);
      s.responder('GET', '/operacoes/op-1', {
        'id': 'op-1',
        'codigo': 'OP-0001',
        'tipo': 'producao',
        'status': 'concluida',
        'localId': 'loc-camara',
        'local': 'Câmara frigorífica',
        'responsavel': 'Maria',
        'registradoPor': 'Funcionária',
        'lotePrincipal': '26100801',
        'iniciadaEm': DateTime.now().toUtc().toIso8601String(),
        'concluidaEm': DateTime.now().toUtc().toIso8601String(),
        'observacao': 'produção de teste',
        'movimentos': [
          movimentoJson(
              id: 'm-rastreio', item: 'COCADA', quantidade: 4100, unidade: 'g')
        ],
      });
      s.responder('GET', '/lotes/26100801/origem', [
        {
          'loteProduto': '26100801',
          'produtoId': 'it-balde',
          'produto': 'COCADA',
          'localId': 'loc-camara',
          'local': 'Câmara frigorífica',
          'operationId': 'op-1',
          'loteInsumo': 'INS-1',
          'insumoId': 'it-castanha',
          'insumo': 'CASTANHA GLACEADA',
          'qtdConsumidaBase': 850,
          'unidade': 'g',
        },
      ]);
    });

    await irParaMovimentacoes(tester);

    expect(find.text('COCADA'), findsOneWidget);
    expect(find.textContaining('4.100 g'), findsOneWidget);
    expect(find.textContaining('responsável Maria'), findsOneWidget);

    await tester.enterText(
        find.widgetWithText(
            TextField, 'Buscar por item, local, lote ou etiqueta'),
        'R000010');
    await tester.pumpAndSettle();
    expect(find.text('COCADA'), findsOneWidget);
    expect(find.text('BROWNIE'), findsNothing);

    await tester.tap(find.text('COCADA'));
    await tester.pumpAndSettle();

    expect(find.text('Operação OP-0001'), findsOneWidget);
    expect(find.text('Origem do lote 26100801'), findsOneWidget);
    expect(find.text('CASTANHA GLACEADA'), findsOneWidget);
  });

  testWidgets('filtros de local e item são enviados para a API',
      (tester) async {
    final m = await abrirApp(tester);

    await irParaMovimentacoes(tester);
    await tester.tap(find.byType(DropdownMenu<String?>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oficina').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownMenu<String?>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('CASTANHA GLACEADA').last);
    await tester.pumpAndSettle();

    final q =
        m.servidor.chamadas('GET', '/movimentos').last.uri.queryParameters;
    expect(q['localId'], 'loc-oficina');
    expect(q['itemId'], 'it-castanha');
    expect(q['limite'], '500');
  });

  testWidgets('aba escondida não dispara a consulta de movimentações livres',
      (tester) async {
    final m = await abrirApp(tester);

    final chamadas = m.servidor.chamadas('GET', '/movimentos');
    expect(chamadas, hasLength(1),
        reason: 'só o histórico de Hoje consulta ao abrir');
    expect(chamadas.single.uri.queryParameters['limite'], '200');
  });

  testWidgets('sem internet avisa que movimentações não foram carregadas',
      (tester) async {
    final m = await abrirApp(tester);
    m.servidor.offline = true;

    await irParaMovimentacoes(tester);

    expect(find.textContaining('As movimentações não foram carregadas.'),
        findsOneWidget);
  });
}
