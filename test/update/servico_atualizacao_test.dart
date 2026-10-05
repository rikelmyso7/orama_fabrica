import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:orama_fabrica2/update/atualizacao.dart';

const _apk = 'https://github.com/rikelmyso7/orama_fabrica/releases/download/v1.2.0/app-release.apk';

Map<String, Object?> _release({
  String tag = 'v1.2.0',
  String body = '✨ Novidades\n- **estoque**: alerta de dúvida\n\n**Comparação completa:** https://github.com/x/y/compare/a...b',
  List<Map<String, Object?>>? assets,
}) =>
    {
      'tag_name': tag,
      'body': body,
      'assets': assets ??
          [
            {'name': 'app-release.aab', 'browser_download_url': 'https://github.com/rikelmyso7/orama_fabrica/releases/download/v1.2.0/app-release.aab'},
            {'name': 'app-release.apk', 'browser_download_url': _apk},
          ],
    };

class _InstaladorFalso implements InstaladorDeApk {
  final urls = <String>[];
  Object? erro;

  @override
  Future<void> baixarEInstalar(String url, {void Function(double progresso)? aoProgredir}) async {
    urls.add(url);
    aoProgredir?.call(1);
    if (erro != null) throw erro!;
  }
}

ServicoAtualizacao _servico(
  http.Client client, {
  String instalada = '1.0.0',
  InstaladorDeApk? instalador,
  String extensao = '.apk',
}) =>
    ServicoAtualizacao(
      client: client,
      extensaoDoPacote: extensao,
      versaoInstalada: () async => instalada,
      instalador: instalador ?? _InstaladorFalso(),
    );

http.Client _responde(int status, Object? corpo) =>
    MockClient((_) async => http.Response(corpo is String ? corpo : jsonEncode(corpo), status, headers: {'content-type': 'application/json; charset=utf-8'}));

void main() {
  group('versaoMaisNova', () {
    test('compara cada parte como número, não como texto', () {
      expect(versaoMaisNova('1.10.0', '1.9.0'), isTrue);
      expect(versaoMaisNova('2.0.0', '1.99.99'), isTrue);
      expect(versaoMaisNova('1.0.1', '1.0.0'), isTrue);
    });

    test('igual ou mais antiga não é atualização', () {
      expect(versaoMaisNova('1.0.0', '1.0.0'), isFalse);
      expect(versaoMaisNova('1.0.0', '1.0.1'), isFalse);
    });

    test('ignora o prefixo v, o número de build e o sufixo de pré-versão', () {
      expect(versaoMaisNova('v1.1.0', '1.0.0+7'), isTrue);
      expect(versaoMaisNova('1.1.0-beta', '1.1.0'), isFalse);
    });

    test('versão ilegível nunca oferece atualização', () {
      expect(versaoMaisNova('abc', '1.0.0'), isFalse);
      expect(versaoMaisNova('1.2', '1.0.0'), isFalse);
      expect(versaoMaisNova('1.2.0', 'x'), isFalse);
    });
  });

  group('ServicoAtualizacao.verificar', () {
    test('devolve a atualização quando a versão do release é maior', () async {
      final a = await _servico(_responde(200, _release())).verificar();
      expect(a, isNotNull);
      expect(a!.versao, '1.2.0');
      expect(a.apkUrl, _apk);
      expect(a.notas, contains('alerta de dúvida'));
    });

    test('consulta o último release do repositório do app', () async {
      Uri? chamada;
      final client = MockClient((r) async {
        chamada = r.url;
        return http.Response(jsonEncode(_release()), 200);
      });
      await _servico(client).verificar();
      expect(chamada.toString(), 'https://api.github.com/repos/rikelmyso7/orama_fabrica/releases/latest');
    });

    test('não há atualização quando já está na última versão', () async {
      expect(await _servico(_responde(200, _release()), instalada: '1.2.0').verificar(), isNull);
      expect(await _servico(_responde(200, _release()), instalada: '1.3.0').verificar(), isNull);
    });

    test('release sem APK é ignorado', () async {
      final sem = _release(assets: [
        {'name': 'app-release.aab', 'browser_download_url': 'https://github.com/rikelmyso7/orama_fabrica/releases/download/v1.2.0/app-release.aab'},
      ]);
      expect(await _servico(_responde(200, sem)).verificar(), isNull);
    });

    test('no Windows escolhe o instalador .exe, não o APK', () async {
      const setup = 'https://github.com/rikelmyso7/orama_fabrica/releases/download/v1.2.0/orama_fabrica_setup_1.2.0.exe';
      final release = _release(assets: [
        {'name': 'app-release.apk', 'browser_download_url': _apk},
        {'name': 'orama_fabrica_setup_1.2.0.exe', 'browser_download_url': setup},
      ]);
      final a = await _servico(_responde(200, release), extensao: '.exe').verificar();
      expect(a!.apkUrl, setup);
    });

    test('release sem o pacote da plataforma (ex.: sem .exe no Windows) é ignorado', () async {
      expect(await _servico(_responde(200, _release()), extensao: '.exe').verificar(), isNull);
    });

    test('APK fora dos releases do repositório não é aceito', () async {
      final malicioso = _release(assets: [
        {'name': 'app-release.apk', 'browser_download_url': 'https://exemplo.com/app-release.apk'},
      ]);
      expect(await _servico(_responde(200, malicioso)).verificar(), isNull);
      final http1 = _release(assets: [
        {'name': 'app-release.apk', 'browser_download_url': 'http://github.com/rikelmyso7/orama_fabrica/releases/download/v1.2.0/app-release.apk'},
      ]);
      expect(await _servico(_responde(200, http1)).verificar(), isNull);
    });

    test('sem release (404), erro do servidor, resposta estranha ou sem rede: nada acontece', () async {
      expect(await _servico(_responde(404, {'message': 'Not Found'})).verificar(), isNull);
      expect(await _servico(_responde(500, 'erro')).verificar(), isNull);
      expect(await _servico(_responde(200, 'isto não é json')).verificar(), isNull);
      expect(await _servico(_responde(200, <Object?>[])).verificar(), isNull);
      expect(await _servico(MockClient((_) async => throw http.ClientException('sem rede'))).verificar(), isNull);
    });

    test('falha ao ler a versão instalada não derruba o app', () async {
      final s = ServicoAtualizacao(
        client: _responde(200, _release()),
        versaoInstalada: () async => throw StateError('plugin indisponível'),
        instalador: _InstaladorFalso(),
      );
      expect(await s.verificar(), isNull);
    });
  });

  group('Atualizacao.notasLegiveis', () {
    test('tira o negrito e o link de comparação das notas', () async {
      final a = (await _servico(_responde(200, _release())).verificar())!;
      expect(a.notasLegiveis, contains('estoque: alerta de dúvida'));
      expect(a.notasLegiveis, isNot(contains('**')));
      expect(a.notasLegiveis, isNot(contains('Comparação')));
    });

    test('sem notas, usa um texto padrão com a versão', () async {
      final a = (await _servico(_responde(200, _release(body: ''))).verificar())!;
      expect(a.notasLegiveis, contains('1.2.0'));
    });
  });

  group('ServicoAtualizacao.instalar', () {
    test('entrega a URL do APK ao instalador', () async {
      final inst = _InstaladorFalso();
      final s = _servico(_responde(200, _release()), instalador: inst);
      final a = (await s.verificar())!;
      await s.instalar(a);
      expect(inst.urls, [_apk]);
    });
  });
}
