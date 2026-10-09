import 'dart:io';

import 'package:http/http.dart' as http;

/// Baixa [url] para [destino], seguindo os redirecionamentos do GitHub, e informa o progresso (0 a 1).
Future<void> baixarArquivo(String url, File destino,
    {void Function(double progresso)? aoProgredir}) async {
  final cliente = http.Client();
  try {
    final resposta = await cliente.send(http.Request('GET', Uri.parse(url)));
    if (resposta.statusCode != 200) {
      throw HttpException('Download recusado (${resposta.statusCode})');
    }
    final total = resposta.contentLength ?? 0;
    var recebido = 0;
    final saida = destino.openWrite();
    try {
      await for (final pedaco in resposta.stream) {
        saida.add(pedaco);
        recebido += pedaco.length;
        if (total > 0) aoProgredir?.call(recebido / total);
      }
    } finally {
      await saida.close();
    }
  } finally {
    cliente.close();
  }
}
