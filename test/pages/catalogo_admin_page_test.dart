import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_de_teste.dart';

const _admin = {
  'id': 'u-adm',
  'login': 'func1',
  'nome': 'Administradora',
  'papel': 'admin'
};

Future<void> abrirCatalogo(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.menu));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Itens'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(prepararDatas);

  testWidgets('quem não é administrador não vê o cadastro do catálogo',
      (tester) async {
    await abrirApp(tester);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('Itens'), findsNothing);
  });

  testWidgets('administrador cria item novo e o catálogo é recarregado',
      (tester) async {
    final m = await abrirApp(tester, usuario: _admin, configurar: (s) {
      s.responder('POST', '/catalogo/itens', {'id': 'it-novo'}, status: 201);
    });
    await abrirCatalogo(tester);
    expect(find.text('COCADA'), findsOneWidget);
    final recargasAntes = m.servidor.chamadas('GET', '/catalogo').length;

    await tester.tap(find.text('Novo item'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nome'), 'AÇÚCAR MASCAVO');
    await tester
        .tap(find.widgetWithText(DropdownButtonFormField<String>, 'Categoria'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Toppings').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar item'));
    await tester.pumpAndSettle();

    final envio = m.servidor.chamadas('POST', '/catalogo/itens').single.corpo
        as Map<String, dynamic>;
    expect(envio['nome'], 'AÇÚCAR MASCAVO');
    expect(envio['categoriaId'], 'cat-toppings');
    expect(envio['unidadeBase'], 'g');
    expect(envio['subgrupo'], isNull);
    expect(m.servidor.chamadas('GET', '/catalogo').length,
        greaterThan(recargasAntes));
    expect(find.text('Novo item'), findsOneWidget,
        reason: 'voltou para a lista do catálogo');
  });

  testWidgets('nome e categoria são obrigatórios e nada é enviado sem eles',
      (tester) async {
    final m = await abrirApp(tester, usuario: _admin);
    await abrirCatalogo(tester);

    await tester.tap(find.text('Novo item'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar item'));
    await tester.pumpAndSettle();

    expect(find.text('Informe o nome.'), findsOneWidget);
    expect(find.text('Escolha a categoria.'), findsOneWidget);
    expect(m.servidor.chamadas('POST', '/catalogo/itens'), isEmpty);
  });

  testWidgets('tirar de uso um item com saldo mostra o motivo da API',
      (tester) async {
    final m = await abrirApp(tester, usuario: _admin, configurar: (s) {
      s.responder(
        'PUT',
        '/catalogo/itens/it-balde',
        {
          'status': 422,
          'codigo': 'regra',
          'detail':
              'O item ainda tem saldo em estoque. Zere o saldo com um ajuste antes de inativar.'
        },
        status: 422,
      );
    });
    await abrirCatalogo(tester);

    await tester.tap(find.text('COCADA'));
    await tester.pumpAndSettle();
    final tirarDeUso = find.widgetWithText(OutlinedButton, 'Tirar de uso');
    await tester.ensureVisible(tirarDeUso);
    await tester.tap(tirarDeUso);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Tirar de uso'));
    await tester.pumpAndSettle();

    final envio = m.servidor
        .chamadas('PUT', '/catalogo/itens/it-balde')
        .single
        .corpo as Map<String, dynamic>;
    expect(envio['ativo'], false);
    expect(find.textContaining('ainda tem saldo em estoque'), findsOneWidget);
    expect(find.text('Editar item'), findsOneWidget,
        reason: 'continua no formulário');
  });

  testWidgets('administrador cria categoria nova', (tester) async {
    final m = await abrirApp(tester, usuario: _admin, configurar: (s) {
      s.responder('POST', '/catalogo/categorias', {'id': 'cat-nova'},
          status: 201);
    });
    await abrirCatalogo(tester);

    await tester.tap(find.byTooltip('Categorias'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nova'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Grãos');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    final envio = m.servidor
        .chamadas('POST', '/catalogo/categorias')
        .single
        .corpo as Map<String, dynamic>;
    expect(envio['nome'], 'Grãos');
  });
}
