import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orama_fabrica2/widgets/alerta_duvida.dart';

import '../support/app_de_teste.dart';

Map<String, Object?> saldoJson(String item, String itemId, num saldoBase,
        {String unidadeBase = 'g', int unidades = 0, String local = 'Câmara frigorífica', String? duvida}) =>
    {
      'localId': 'loc-camara',
      'local': local,
      'itemId': itemId,
      'item': item,
      'unidadeBase': unidadeBase,
      'saldoBase': saldoBase,
      'saldoUnidades': unidades,
      if (duvida != null) 'duvida': duvida,
    };

Future<void> irParaEstoque(WidgetTester tester) async {
  await tester.tap(find.text('Estoque').last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(prepararDatas);

  testWidgets('mostra o saldo por local, em kg quando passa de 1000 g, e esconde saldo zero', (tester) async {
    await abrirApp(tester, configurar: (s) {
      s.responder('GET', '/saldo', [
        saldoJson('COCADA', 'it-balde', 7950, unidades: 2),
        saldoJson('BROWNIE', 'it-cookie', 12, unidadeBase: 'un'),
        saldoJson('ZERADO', 'it-zero', 0),
        saldoJson('CASTANHA GLACEADA', 'it-castanha', 850, local: 'Oficina'),
      ]);
    });

    await irParaEstoque(tester);

    expect(find.text('Câmara frigorífica'), findsOneWidget);
    expect(find.text('Oficina'), findsOneWidget);
    expect(find.text('7,95 kg'), findsOneWidget);
    expect(find.text('2 recipientes'), findsOneWidget);
    expect(find.text('12 un'), findsOneWidget);
    expect(find.text('850 g'), findsOneWidget);
    expect(find.text('ZERADO'), findsNothing);
  });

  testWidgets('saldo negativo aparece em vermelho', (tester) async {
    await abrirApp(tester, configurar: (s) => s.responder('GET', '/saldo', [saldoJson('COCADA', 'it-balde', -250)]));

    await irParaEstoque(tester);

    final texto = tester.widget<Text>(find.text('-250 g'));
    expect(texto.style!.color, Colors.red);
  });

  testWidgets('a busca filtra os itens sem diferenciar acento', (tester) async {
    await abrirApp(tester, configurar: (s) {
      s.responder('GET', '/saldo', [saldoJson('PAÇOCA', 'a', 10), saldoJson('COCADA', 'it-balde', 20)]);
    });
    await irParaEstoque(tester);

    await tester.enterText(find.byType(TextField), 'pacoca');
    await tester.pumpAndSettle();

    expect(find.text('PAÇOCA'), findsOneWidget);
    expect(find.text('COCADA'), findsNothing);
  });

  testWidgets('tocar em um balde mostra cada recipiente com peso, lote e validade', (tester) async {
    final m = await abrirApp(tester, configurar: (s) {
      s.responder('GET', '/saldo', [saldoJson('COCADA', 'it-balde', 7950, unidades: 2)]);
      s.responder('GET', '/recipientes', [
        {
          'recipienteId': 'r1', 'etiqueta': 'R000002', 'localId': 'loc-camara', 'local': 'Câmara frigorífica',
          'itemId': 'it-balde', 'item': 'COCADA', 'pesoBase': 3850, 'lote': 'L7', 'validade': '2027-03-01',
          'produzidoEm': '2026-10-02T12:00:00Z',
        },
        {
          'recipienteId': 'r2', 'etiqueta': 'R000001', 'localId': 'loc-camara', 'local': 'Câmara frigorífica',
          'itemId': 'it-balde', 'item': 'COCADA', 'pesoBase': 4100, 'lote': 'L7', 'validade': null,
          'produzidoEm': '2026-10-02T12:00:00Z',
        },
      ]);
    });
    await irParaEstoque(tester);

    await tester.tap(find.text('COCADA'));
    await tester.pumpAndSettle();

    expect(find.textContaining('menor validade primeiro'), findsOneWidget);
    expect(find.text('R000002 · 3,85 kg'), findsOneWidget);
    expect(find.text('R000001 · 4,1 kg'), findsOneWidget);
    expect(find.textContaining('validade 01/03/2027'), findsOneWidget);
    expect(find.textContaining('Lote L7'), findsNWidgets(2));
    expect(m.servidor.chamadas('GET', '/recipientes').single.uri.queryParameters, {'itemId': 'it-balde'});
  });

  testWidgets('item comum não abre lista de recipientes', (tester) async {
    final m = await abrirApp(tester,
        configurar: (s) => s.responder('GET', '/saldo', [saldoJson('BROWNIE', 'it-cookie', 12, unidadeBase: 'un')]));
    await irParaEstoque(tester);

    await tester.tap(find.text('BROWNIE'));
    await tester.pumpAndSettle();

    expect(m.servidor.chamadas('GET', '/recipientes'), isEmpty);
  });

  testWidgets('sem internet avisa que o saldo não foi carregado', (tester) async {
    final m = await abrirApp(tester);
    m.servidor.offline = true;
    await irParaEstoque(tester);

    await tester.drag(find.byType(ListView).last, const Offset(0, 900));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.textContaining('O saldo não foi carregado.'), findsOneWidget);
  });

  group('alertas de dado duvidoso', () {
    const duvida = 'contagem sem valor (não entra no saldo); soma un + resto - definir';

    testWidgets('item com dúvida mostra o alerta, e tocar nele explica cada motivo', (tester) async {
      await abrirApp(tester, configurar: (s) {
        s.responder('GET', '/saldo', [
          saldoJson('COCADA', 'it-balde', 7950),
          saldoJson('POLPA CAJÁ', 'it-caja', 40, unidadeBase: 'un', duvida: duvida),
        ]);
      });
      await irParaEstoque(tester);

      expect(find.byType(AlertaDuvida), findsOneWidget, reason: 'só o item duvidoso tem alerta');

      await tester.tap(find.byType(AlertaDuvida));
      await tester.pumpAndSettle();

      expect(find.text('POLPA CAJÁ'), findsNWidgets(2), reason: 'na lista e no título da explicação');
      expect(find.textContaining('contagem sem valor'), findsOneWidget);
      expect(find.textContaining('soma un + resto'), findsOneWidget);
    });

    testWidgets('saldo zero com alerta continua aparecendo (senão a contagem sem valor some)', (tester) async {
      await abrirApp(tester, configurar: (s) {
        s.responder('GET', '/saldo', [
          saldoJson('SEM VALOR', 'it-sv', 0, duvida: 'contagem sem valor (não entra no saldo)'),
          saldoJson('ZERADO', 'it-zero', 0),
        ]);
      });

      await irParaEstoque(tester);

      expect(find.text('SEM VALOR'), findsOneWidget);
      expect(find.text('ZERADO'), findsNothing);
    });

    testWidgets('o filtro "Só com alerta" mostra apenas os itens duvidosos e conta quantos são', (tester) async {
      await abrirApp(tester, configurar: (s) {
        s.responder('GET', '/saldo', [
          saldoJson('COCADA', 'it-balde', 7950),
          saldoJson('POLPA CAJÁ', 'it-caja', 40, unidadeBase: 'un', duvida: duvida),
        ]);
      });
      await irParaEstoque(tester);

      await tester.tap(find.text('Só com alerta (1)'));
      await tester.pumpAndSettle();

      expect(find.text('POLPA CAJÁ'), findsOneWidget);
      expect(find.text('COCADA'), findsNothing);
    });

    testWidgets('sem nenhum item duvidoso o filtro nem aparece', (tester) async {
      await abrirApp(tester, configurar: (s) => s.responder('GET', '/saldo', [saldoJson('COCADA', 'it-balde', 7950)]));

      await irParaEstoque(tester);

      expect(find.textContaining('Só com alerta'), findsNothing);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });
  });

  testWidgets('sem nenhum saldo mostra o aviso', (tester) async {
    await abrirApp(tester);

    await irParaEstoque(tester);

    expect(find.text('Nenhum item com saldo.'), findsOneWidget);
  });
}
