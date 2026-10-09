import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:orama_fabrica2/app.dart';

import 'servidor_falso.dart';

Future<void> prepararDatas() => initializeDateFormatting('pt_BR');

/// Movimento no formato da API, com valores padrão, para os testes de histórico.
Map<String, Object?> movimentoJson({
  String id = 'm1',
  String tipo = 'entrada',
  String item = 'BROWNIE',
  num quantidade = 12,
  String unidade = 'un',
  String local = 'Câmara frigorífica',
  bool estornado = false,
  String? estornaId,
  String? lote,
  String? etiqueta,
  String? operationId,
  String? validade,
  String? responsavel,
  String? motivo,
  String? autorizadoPor,
  String? textoOriginal,
  String? revisar,
  DateTime? quando,
}) =>
    {
      'id': id,
      'tipo': tipo,
      'ocorridoEm': (quando ?? DateTime.now()).toUtc().toIso8601String(),
      'itemId': 'it-cookie',
      'item': item,
      'localId': 'loc-camara',
      'local': local,
      'quantidade': quantidade,
      'unidade': unidade,
      'qtdBase': quantidade,
      'origem': 'producao',
      'lote': lote,
      if (validade != null) 'validade': validade,
      'etiqueta': etiqueta,
      'usuario': 'Funcionária',
      if (responsavel != null) 'responsavel': responsavel,
      if (operationId != null) 'operationId': operationId,
      'estornaId': estornaId,
      'estornado': estornado,
      'motivo': motivo,
      'autorizadoPor': autorizadoPor,
      'textoOriginal': textoOriginal,
      'revisar': revisar,
    };

/// Abre o app inteiro com o servidor falso. Com [logado], a sessão já existe; sem, o app começa no login.
Future<Montagem> abrirApp(
  WidgetTester tester, {
  bool logado = true,
  Map<String, Object?> usuario = usuarioFabricaJson,
  void Function(ServidorFalso servidor)? configurar,
  Montagem? montagem,
}) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final m = montagem ?? montar();
  m.servidor.responder('POST', '/auth/login', loginJson(usuario: usuario));
  m.servidor.responder('GET', '/catalogo', catalogoJson());
  m.servidor.responder('GET', '/movimentos', <Object?>[]);
  m.servidor.responder('GET', '/saldo', <Object?>[]);
  configurar?.call(m.servidor);

  if (logado) await m.deps.auth.entrar('func1', 'senha-123');
  await tester.pumpWidget(OramaApp(deps: m.deps));
  await tester.pumpAndSettle();
  return m;
}

/// Abre a tela de nova entrada a partir da tela inicial.
Future<void> abrirNovaEntrada(WidgetTester tester) async {
  await tester.tap(find.text('Nova entrada'));
  await tester.pumpAndSettle();
}
