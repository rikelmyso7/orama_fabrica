import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app.dart';
import 'config/app_config.dart';
import 'storage/storage.dart';
import 'update/atualizacao.dart';
import 'update/instalador_android.dart';
import 'update/instalador_windows.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  await GetStorage.init();

  final deps = AppDependencias.criar(
    baseUrl: AppConfig.apiUrl,
    store: GetStorageKeyValueStore(),
    secure: FlutterSecureStore(),
    atualizacao: _servicoDeAtualizacao(),
  );
  runApp(OramaApp(deps: deps, problemaDeConfiguracao: AppConfig.problema()));
}

/// Atualização pelos releases do GitHub: APK no Android, .exe (instalador) no Windows. Nas demais plataformas, desligada.
ServicoAtualizacao? _servicoDeAtualizacao() {
  if (kIsWeb) return null;
  Future<String> versaoInstalada() async => (await PackageInfo.fromPlatform()).version;
  if (Platform.isAndroid) {
    return ServicoAtualizacao(versaoInstalada: versaoInstalada, instalador: InstaladorAndroid());
  }
  if (Platform.isWindows) {
    return ServicoAtualizacao(
      versaoInstalada: versaoInstalada,
      instalador: InstaladorWindows(),
      extensaoDoPacote: '.exe',
    );
  }
  return null;
}
