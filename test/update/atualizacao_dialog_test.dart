import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:orama_fabrica2/update/atualizacao.dart';

import '../support/app_de_teste.dart';
import '../support/servidor_falso.dart';

const _apk = 'https://github.com/rikelmyso7/orama_fabrica/releases/download/v1.2.0/app-release.apk';

class _Instalador implements InstaladorDeApk {
  final urls = <String>[];
  Object? erro;

  @override
  Future<void> baixarEInstalar(String url, {void Function(double progresso)? aoProgredir}) async {
    urls.add(url);
    if (erro != null) throw erro!;
  }
}

ServicoAtualizacao _servico(_Instalador inst, {String tag = 'v1.2.0'}) => ServicoAtualizacao(
      client: MockClient((_) async => http.Response.bytes(
            utf8.encode(jsonEncode({
              'tag_name': tag,
              'body': '🐛 Correções\n- **estoque**: corrige o saldo',
              'assets': [
                {'name': 'app-release.apk', 'browser_download_url': _apk}
              ],
            })),
            200,
          )),
      versaoInstalada: () async => '1.0.0',
      instalador: inst,
    );

Future<void> _abrir(WidgetTester tester, ServicoAtualizacao servico) =>
    abrirApp(tester, montagem: montar(atualizacao: servico));

void main() {
  setUpAll(prepararDatas);

  testWidgets('versão nova: oferece a atualização com as notas', (tester) async {
    await _abrir(tester, _servico(_Instalador()));

    expect(find.text('Nova versão disponível'), findsOneWidget);
    expect(find.textContaining('1.2.0'), findsWidgets);
    expect(find.textContaining('corrige o saldo'), findsOneWidget);
  });

  testWidgets('"Agora não" fecha o aviso e não instala nada', (tester) async {
    final inst = _Instalador();
    await _abrir(tester, _servico(inst));

    await tester.tap(find.text('Agora não'));
    await tester.pumpAndSettle();

    expect(find.text('Nova versão disponível'), findsNothing);
    expect(inst.urls, isEmpty);
  });

  testWidgets('"Atualizar" baixa o APK do release e fecha o aviso', (tester) async {
    final inst = _Instalador();
    await _abrir(tester, _servico(inst));

    await tester.tap(find.text('Atualizar'));
    await tester.pumpAndSettle();

    expect(inst.urls, [_apk]);
    expect(find.text('Nova versão disponível'), findsNothing);
  });

  testWidgets('falha no download mostra o erro e permite tentar de novo', (tester) async {
    final inst = _Instalador()..erro = http.ClientException('sem rede');
    await _abrir(tester, _servico(inst));

    await tester.tap(find.text('Atualizar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Não foi possível baixar'), findsOneWidget);
    expect(find.text('Atualizar'), findsOneWidget);
  });

  testWidgets('sem versão nova, nenhum aviso aparece', (tester) async {
    await _abrir(tester, _servico(_Instalador(), tag: 'v1.0.0'));

    expect(find.text('Nova versão disponível'), findsNothing);
  });

  testWidgets('sem serviço de atualização, o app abre normalmente', (tester) async {
    await abrirApp(tester);
    expect(find.text('Nova versão disponível'), findsNothing);
  });
}
