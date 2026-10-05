import '../util/numero.dart';

/// Uma linha de entrada que o funcionário lançou e que ainda não foi aceita pela API.
/// O [id] é gerado no aparelho: reenviar a mesma linha nunca duplica o lançamento.
class EntradaPendente {
  final String id;
  final String usuarioId;
  final String itemId;
  final String itemNome;
  final String? varianteId;
  final String? varianteRotulo;
  final String? localNome;

  /// Quantidade como será enviada ("4.1", "3.85"): texto, para não perder casas decimais.
  final String quantidade;
  final String unidade;

  /// 1 para balde, cuba e pote (uma linha por recipiente).
  final int? unidades;
  final String origem;
  final String? lote;
  final DateTime? validade;
  final String? documento;
  final String? textoOriginal;
  final DateTime ocorridoEm;

  /// Motivo da recusa pela API. Linhas com erro não são reenviadas sozinhas.
  final String? erro;

  const EntradaPendente({
    required this.id,
    required this.usuarioId,
    required this.itemId,
    required this.itemNome,
    required this.quantidade,
    required this.unidade,
    required this.origem,
    required this.ocorridoEm,
    this.varianteId,
    this.varianteRotulo,
    this.localNome,
    this.unidades,
    this.lote,
    this.validade,
    this.documento,
    this.textoOriginal,
    this.erro,
  });

  EntradaPendente comErro(String? motivo) => EntradaPendente(
        id: id,
        usuarioId: usuarioId,
        itemId: itemId,
        itemNome: itemNome,
        quantidade: quantidade,
        unidade: unidade,
        origem: origem,
        ocorridoEm: ocorridoEm,
        varianteId: varianteId,
        varianteRotulo: varianteRotulo,
        localNome: localNome,
        unidades: unidades,
        lote: lote,
        validade: validade,
        documento: documento,
        textoOriginal: textoOriginal,
        erro: motivo,
      );

  /// "4,1 kg", para mostrar na tela.
  String get descricao => Numero.formatar(double.parse(quantidade), unidade);

  /// Corpo de um item de POST /entradas.
  Map<String, dynamic> paraApi() => {
        'id': id,
        'itemId': itemId,
        if (varianteId != null) 'varianteId': varianteId,
        'quantidade': double.parse(quantidade),
        'unidade': unidade,
        if (unidades != null) 'unidades': unidades,
        'origem': origem,
        if (lote != null && lote!.trim().isNotEmpty) 'lote': lote!.trim(),
        if (validade != null) 'validade': _dia(validade!),
        if (documento != null && documento!.trim().isNotEmpty) 'documento': documento!.trim(),
        if (textoOriginal != null) 'textoOriginal': textoOriginal,
        'ocorridoEm': ocorridoEm.toUtc().toIso8601String(),
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'usuarioId': usuarioId,
        'itemId': itemId,
        'itemNome': itemNome,
        'varianteId': varianteId,
        'varianteRotulo': varianteRotulo,
        'localNome': localNome,
        'quantidade': quantidade,
        'unidade': unidade,
        'unidades': unidades,
        'origem': origem,
        'lote': lote,
        'validade': validade == null ? null : _dia(validade!),
        'documento': documento,
        'textoOriginal': textoOriginal,
        'ocorridoEm': ocorridoEm.toUtc().toIso8601String(),
        'erro': erro,
      };

  factory EntradaPendente.fromJson(Map<String, dynamic> j) => EntradaPendente(
        id: j['id'] as String,
        usuarioId: j['usuarioId'] as String,
        itemId: j['itemId'] as String,
        itemNome: j['itemNome'] as String,
        varianteId: j['varianteId'] as String?,
        varianteRotulo: j['varianteRotulo'] as String?,
        localNome: j['localNome'] as String?,
        quantidade: j['quantidade'] as String,
        unidade: j['unidade'] as String,
        unidades: j['unidades'] as int?,
        origem: j['origem'] as String,
        lote: j['lote'] as String?,
        validade: j['validade'] == null ? null : DateTime.parse(j['validade'] as String),
        documento: j['documento'] as String?,
        textoOriginal: j['textoOriginal'] as String?,
        ocorridoEm: DateTime.parse(j['ocorridoEm'] as String).toLocal(),
        erro: j['erro'] as String?,
      );

  static String _dia(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
