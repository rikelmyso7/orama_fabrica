import 'package:flutter_test/flutter_test.dart';
import 'package:orama_fabrica2/config/app_config.dart';

void main() {
  group('AppConfig.problema', () {
    test('endereço vazio é problema', () {
      expect(AppConfig.problema(url: '', producao: false), contains('API_URL'));
    });

    test('endereço inválido é problema', () {
      expect(AppConfig.problema(url: 'isto não é url', producao: false), contains('inválido'));
      expect(AppConfig.problema(url: 'http://', producao: false), contains('inválido'));
    });

    test('em desenvolvimento aceita http', () {
      expect(AppConfig.problema(url: 'http://10.0.2.2:8080', producao: false), isNull);
    });

    test('em produção só aceita https', () {
      expect(AppConfig.problema(url: 'http://api.exemplo.com.br', producao: true), contains('HTTPS'));
      expect(AppConfig.problema(url: 'https://api.exemplo.com.br', producao: true), isNull);
    });
  });
}
