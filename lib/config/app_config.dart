import 'package:flutter/foundation.dart';

/// Configuração definida na compilação:
///   flutter run --dart-define-from-file=env/dev.json
///   flutter build apk --dart-define-from-file=env/prod.json   (no CI, montado a partir de secrets)
class AppConfig {
  const AppConfig._();

  /// Sem valor padrão: o endereço de produção não fica no repositório público, vem do env do build.
  static const String apiUrl = String.fromEnvironment('API_URL');

  /// Mensagem de problema na configuração, ou null se está tudo certo.
  /// Em versão de produção o endereço precisa ser HTTPS: senha e token não trafegam em texto puro.
  static String? problema({String url = apiUrl, bool producao = kReleaseMode}) {
    if (url.isEmpty) {
      return 'O endereço da API não foi configurado. Compile com --dart-define=API_URL=<endereço>.';
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return 'O endereço da API é inválido: $url';
    }
    if (producao && uri.scheme != 'https') {
      return 'Em produção, o endereço da API precisa ser HTTPS.';
    }
    return null;
  }
}
