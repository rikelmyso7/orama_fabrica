import '../util/numero.dart';

class LinhaOperacaoPendente {
  final String id;
  final String tipo;
  final String itemId;
  final String itemNome;
  final String? varianteId;
  final String? varianteRotulo;
  final String quantidade;
  final String unidade;
  final int? unidades;
  final String? lote;
  final DateTime? validade;
  final String? documento;
  final String? textoOriginal;
  final DateTime ocorridoEm;

  const LinhaOperacaoPendente({
    required this.id,
    required this.tipo,
    required this.itemId,
    required this.itemNome,
    required this.quantidade,
    required this.unidade,
    required this.ocorridoEm,
    this.varianteId,
    this.varianteRotulo,
    this.unidades,
    this.lote,
    this.validade,
    this.documento,
    this.textoOriginal,
  });

  String get descricao => Numero.formatar(double.parse(quantidade), unidade);

  Map<String, dynamic> paraApi() => {
        'id': id,
        'tipo': tipo,
        'itemId': itemId,
        if (varianteId != null) 'varianteId': varianteId,
        'quantidade': double.parse(quantidade),
        'unidade': unidade,
        if (unidades != null) 'unidades': unidades,
        if (lote != null && lote!.trim().isNotEmpty) 'lote': lote!.trim(),
        if (validade != null) 'validade': _dia(validade!),
        if (documento != null && documento!.trim().isNotEmpty)
          'documento': documento!.trim(),
        if (textoOriginal != null) 'textoOriginal': textoOriginal,
        'ocorridoEm': ocorridoEm.toUtc().toIso8601String(),
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'tipo': tipo,
        'itemId': itemId,
        'itemNome': itemNome,
        'varianteId': varianteId,
        'varianteRotulo': varianteRotulo,
        'quantidade': quantidade,
        'unidade': unidade,
        'unidades': unidades,
        'lote': lote,
        'validade': validade == null ? null : _dia(validade!),
        'documento': documento,
        'textoOriginal': textoOriginal,
        'ocorridoEm': ocorridoEm.toUtc().toIso8601String(),
      };

  factory LinhaOperacaoPendente.fromJson(Map<String, dynamic> j) =>
      LinhaOperacaoPendente(
        id: j['id'] as String,
        tipo: j['tipo'] as String,
        itemId: j['itemId'] as String,
        itemNome: j['itemNome'] as String,
        varianteId: j['varianteId'] as String?,
        varianteRotulo: j['varianteRotulo'] as String?,
        quantidade: j['quantidade'] as String,
        unidade: j['unidade'] as String,
        unidades: j['unidades'] as int?,
        lote: j['lote'] as String?,
        validade: j['validade'] == null
            ? null
            : DateTime.parse(j['validade'] as String),
        documento: j['documento'] as String?,
        textoOriginal: j['textoOriginal'] as String?,
        ocorridoEm: DateTime.parse(j['ocorridoEm'] as String).toLocal(),
      );

  static String _dia(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class OperacaoPendente {
  final String id;
  final String usuarioId;
  final String tipo;
  final String localId;
  final String localNome;
  final String? responsavelId;
  final String responsavelNome;
  final String? lotePrincipal;
  final DateTime iniciadaEm;
  final String? observacao;
  final List<LinhaOperacaoPendente> movimentos;
  final String? erro;

  const OperacaoPendente({
    required this.id,
    required this.usuarioId,
    required this.tipo,
    required this.localId,
    required this.localNome,
    required this.responsavelNome,
    required this.iniciadaEm,
    required this.movimentos,
    this.responsavelId,
    this.lotePrincipal,
    this.observacao,
    this.erro,
  });

  OperacaoPendente comErro(String? motivo) => OperacaoPendente(
        id: id,
        usuarioId: usuarioId,
        tipo: tipo,
        localId: localId,
        localNome: localNome,
        responsavelId: responsavelId,
        responsavelNome: responsavelNome,
        lotePrincipal: lotePrincipal,
        iniciadaEm: iniciadaEm,
        observacao: observacao,
        movimentos: movimentos,
        erro: motivo,
      );

  Map<String, dynamic> paraApi() => {
        'id': id,
        'tipo': tipo,
        'localId': localId,
        if (responsavelId != null) 'responsavelId': responsavelId,
        if (lotePrincipal != null && lotePrincipal!.trim().isNotEmpty)
          'lotePrincipal': lotePrincipal!.trim(),
        'iniciadaEm': iniciadaEm.toUtc().toIso8601String(),
        'concluidaEm': DateTime.now().toUtc().toIso8601String(),
        if (observacao != null && observacao!.trim().isNotEmpty)
          'observacao': observacao!.trim(),
        'movimentos': movimentos.map((e) => e.paraApi()).toList(),
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'usuarioId': usuarioId,
        'tipo': tipo,
        'localId': localId,
        'localNome': localNome,
        'responsavelId': responsavelId,
        'responsavelNome': responsavelNome,
        'lotePrincipal': lotePrincipal,
        'iniciadaEm': iniciadaEm.toUtc().toIso8601String(),
        'observacao': observacao,
        'movimentos': movimentos.map((e) => e.toJson()).toList(),
        'erro': erro,
      };

  factory OperacaoPendente.fromJson(Map<String, dynamic> j) => OperacaoPendente(
        id: j['id'] as String,
        usuarioId: j['usuarioId'] as String,
        tipo: j['tipo'] as String,
        localId: j['localId'] as String,
        localNome: j['localNome'] as String,
        responsavelId: j['responsavelId'] as String?,
        responsavelNome: j['responsavelNome'] as String,
        lotePrincipal: j['lotePrincipal'] as String?,
        iniciadaEm: DateTime.parse(j['iniciadaEm'] as String).toLocal(),
        observacao: j['observacao'] as String?,
        movimentos: ((j['movimentos'] as List?) ?? const [])
            .map((e) =>
                LinhaOperacaoPendente.fromJson(e as Map<String, dynamic>))
            .toList(),
        erro: j['erro'] as String?,
      );
}
