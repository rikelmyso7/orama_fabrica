import 'dart:io';

import 'package:app_installer/app_installer.dart';
import 'package:path_provider/path_provider.dart';

import 'atualizacao.dart';
import 'download.dart';

/// Baixa o APK para a pasta temporária do app e abre o instalador do Android.
class InstaladorAndroid implements InstaladorDeApk {
  @override
  Future<void> baixarEInstalar(String url, {void Function(double progresso)? aoProgredir}) async {
    final pasta = await getTemporaryDirectory();
    final arquivo = File('${pasta.path}/orama_fabrica_update.apk');
    await baixarArquivo(url, arquivo, aoProgredir: aoProgredir);
    await AppInstaller.installApk(arquivo.path);
  }
}
