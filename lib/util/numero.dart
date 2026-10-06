import 'package:intl/intl.dart';

/// Leitura e formatação de quantidades, no padrão brasileiro (vírgula decimal).
class Numero {
  const Numero._();

  static const double maximo = 99999999999.999;

  /// Lê o que o usuário digitou: "3,85", "3.85", "1.234,5". Devolve null se não for um número
  /// positivo, se tiver mais de 3 casas decimais ou for grande demais (limites do banco).
  static double? lerQuantidade(String? texto) {
    if (texto == null) return null;
    var t = texto.trim().replaceAll(' ', '');
    if (t.isEmpty) return null;
    if (t.contains(',')) {
      t = t.replaceAll('.', '').replaceAll(',', '.');
    }
    if (!RegExp(r'^\d+(\.\d{1,3})?$').hasMatch(t)) return null;
    final v = double.tryParse(t);
    if (v == null || v <= 0 || v > maximo) return null;
    return v;
  }

  /// Texto para enviar à API, sem notação científica nem ponto de milhar.
  static String paraApi(double v) {
    final t = v.toStringAsFixed(3);
    return t.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  /// "7,95 kg" para 7950 g; "850 g" para 850 g. Outras unidades saem como vieram.
  static String formatarBase(double valor, String unidadeBase) {
    final f = NumberFormat('#,##0.###', 'pt_BR');
    if (unidadeBase == 'g' && valor.abs() >= 1000) {
      return '${f.format(valor / 1000)} kg';
    }
    if (unidadeBase == 'ml' && valor.abs() >= 1000) {
      return '${f.format(valor / 1000)} L';
    }
    return '${f.format(valor)} $unidadeBase';
  }

  static String formatar(double valor, String unidade) =>
      '${NumberFormat('#,##0.###', 'pt_BR').format(valor)} $unidade';
}
