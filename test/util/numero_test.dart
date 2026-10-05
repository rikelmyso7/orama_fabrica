import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:orama_fabrica2/util/numero.dart';
import 'package:orama_fabrica2/util/texto.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  group('Numero.lerQuantidade', () {
    test('aceita vírgula e ponto decimais', () {
      expect(Numero.lerQuantidade('3,85'), 3.85);
      expect(Numero.lerQuantidade('3.85'), 3.85);
      expect(Numero.lerQuantidade(' 4100 '), 4100);
    });

    test('entende ponto de milhar quando há vírgula decimal', () {
      expect(Numero.lerQuantidade('1.234,5'), 1234.5);
    });

    test('recusa vazio, zero, negativo, texto e mais de 3 casas', () {
      for (final ruim in ['', '   ', '0', '0,0', '-3', 'abc', '3,8555', '1,2,3', '--', '3 kg', null]) {
        expect(Numero.lerQuantidade(ruim), isNull, reason: '"$ruim" deveria ser recusado');
      }
    });

    test('recusa valor acima do limite do banco', () {
      expect(Numero.lerQuantidade('100000000000'), isNull);
      expect(Numero.lerQuantidade('99999999999,999'), 99999999999.999);
    });
  });

  group('Numero.paraApi', () {
    test('não usa notação científica nem zeros à toa', () {
      expect(Numero.paraApi(4100), '4100');
      expect(Numero.paraApi(3.85), '3.85');
      expect(Numero.paraApi(0.001), '0.001');
      expect(Numero.paraApi(1234567.5), '1234567.5');
    });
  });

  group('formatação', () {
    test('gramas viram kg a partir de 1000 e ml viram L', () {
      expect(Numero.formatarBase(7950, 'g'), '7,95 kg');
      expect(Numero.formatarBase(850, 'g'), '850 g');
      expect(Numero.formatarBase(1500, 'ml'), '1,5 L');
      expect(Numero.formatarBase(12, 'un'), '12 un');
      expect(Numero.formatarBase(-250, 'g'), '-250 g');
    });

    test('formatar usa vírgula decimal', () {
      expect(Numero.formatar(4.1, 'kg'), '4,1 kg');
      expect(Numero.formatar(1234.5, 'g'), '1.234,5 g');
    });
  });

  group('Texto', () {
    test('busca sem acento e sem diferenciar maiúsculas', () {
      expect(Texto.contem('PAÇOCA COM AMENDOIM', 'pacoca'), isTrue);
      expect(Texto.contem('Açaí da Amazônia', 'ACAI'), isTrue);
      expect(Texto.contem('COCADA', 'brigadeiro'), isFalse);
      expect(Texto.normalizar('  ÁÉÍÓÚ ãõ ç  '), 'aeiou ao c');
    });
  });
}
