import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'atualizacao.dart';
import 'download.dart';

/// Baixa o instalador (.exe, gerado no release) e o executa. O instalador fecha o app aberto,
/// substitui os arquivos e reabre o app, como no orama_admin.
class InstaladorWindows implements InstaladorDeApk {
  @override
  Future<void> baixarEInstalar(String url,
      {void Function(double progresso)? aoProgredir}) async {
    final pasta = await getTemporaryDirectory();
    final arquivo =
        File('${pasta.path}${Platform.pathSeparator}orama_fabrica_setup.exe');
    await baixarArquivo(url, arquivo, aoProgredir: aoProgredir);
    await Process.start(arquivo.path, const [],
        mode: ProcessStartMode.detached);
  }
}
