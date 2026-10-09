import 'dart:convert';

import 'package:http/http.dart' as http;

/// Repositório de onde saem as versões do app (GitHub Releases, público: não precisa de token).
const repositorioDoApp = 'rikelmyso7/orama_fabrica';

const _prefixoDoApk = 'https://github.com/$repositorioDoApp/releases/download/';

/// Uma versão publicada, mais nova que a instalada. [apkUrl] é o pacote da plataforma: `.apk` no
/// Android, `.exe` (instalador) no Windows.
class Atualizacao {
  const Atualizacao(
      {required this.versao, required this.notas, required this.apkUrl});

  final String versao;
  final String notas;
  final String apkUrl;

  /// Notas do release sem a marcação de Markdown e sem o link de comparação, para mostrar na tela.
  String get notasLegiveis {
    final linhas = notas
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('**Comparação'))
        .map((l) => l.replaceAll('**', ''))
        .join('\n')
        .trim();
    return linhas.isEmpty ? 'Atualize para a versão $versao.' : linhas;
  }
}

/// Baixa o pacote e entrega ao sistema: instalador do Android ou instalador do Windows.
abstract class InstaladorDeApk {
  Future<void> baixarEInstalar(String url,
      {void Function(double progresso)? aoProgredir});
}

/// `true` se [remota] é maior que [local]. Compara major.minor.patch como números; ignora `v`,
/// `+build` e `-pré-versão`. Versão ilegível nunca é "mais nova".
bool versaoMaisNova(String remota, String local) {
  final r = _partes(remota);
  final l = _partes(local);
  if (r == null || l == null) return false;
  for (var i = 0; i < 3; i++) {
    if (r[i] != l[i]) return r[i] > l[i];
  }
  return false;
}

List<int>? _partes(String versao) {
  var v = versao.trim();
  if (v.startsWith('v')) v = v.substring(1);
  v = v.split('+').first.split('-').first;
  final partes = v.split('.');
  if (partes.length != 3) return null;
  final numeros = partes.map(int.tryParse).toList();
  return numeros.contains(null) ? null : numeros.cast<int>();
}

/// Consulta o último release no GitHub e instala o APK. Opcional para o usuário: qualquer falha
/// (sem rede, sem release, resposta estranha) só significa "sem atualização agora".
class ServicoAtualizacao {
  ServicoAtualizacao({
    required this.versaoInstalada,
    required this.instalador,
    this.extensaoDoPacote = '.apk',
    http.Client? client,
  }) : _client = client ?? http.Client();

  final Future<String> Function() versaoInstalada;
  final InstaladorDeApk instalador;

  /// Qual arquivo do release serve a esta plataforma: `.apk` (Android) ou `.exe` (Windows).
  final String extensaoDoPacote;
  final http.Client _client;

  static final _ultimoRelease = Uri.parse(
      'https://api.github.com/repos/$repositorioDoApp/releases/latest');

  Future<Atualizacao?> verificar() async {
    try {
      final instalada = await versaoInstalada();
      final resposta = await _client.get(_ultimoRelease, headers: {
        'Accept': 'application/vnd.github+json'
      }).timeout(const Duration(seconds: 10));
      if (resposta.statusCode != 200) return null;

      final dados = jsonDecode(utf8.decode(resposta.bodyBytes));
      if (dados is! Map<String, dynamic>) return null;

      final versao = (dados['tag_name'] as String? ?? '').replaceFirst('v', '');
      if (!versaoMaisNova(versao, instalada)) return null;

      final apkUrl = _urlDoPacote(dados['assets']);
      if (apkUrl == null) return null;

      return Atualizacao(
          versao: versao,
          notas: (dados['body'] as String? ?? '').trim(),
          apkUrl: apkUrl);
    } catch (_) {
      return null;
    }
  }

  Future<void> instalar(Atualizacao a,
          {void Function(double progresso)? aoProgredir}) =>
      instalador.baixarEInstalar(a.apkUrl, aoProgredir: aoProgredir);

  /// Só aceita pacote hospedado nos releases do próprio repositório, por HTTPS.
  String? _urlDoPacote(Object? assets) {
    if (assets is! List) return null;
    for (final asset in assets) {
      if (asset is! Map) continue;
      final nome = asset['name'];
      final url = asset['browser_download_url'];
      if (nome is String &&
          nome.endsWith(extensaoDoPacote) &&
          url is String &&
          url.startsWith(_prefixoDoApk)) {
        return url;
      }
    }
    return null;
  }
}
