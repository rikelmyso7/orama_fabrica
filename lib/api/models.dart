// Modelos das respostas da orama_api. Escritos à mão: poucos campos, sem gerador de código.

double _numero(dynamic v) => (v as num).toDouble();

DateTime _data(dynamic v) => DateTime.parse(v as String).toLocal();

class UsuarioLogado {
  final String id;
  final String login;
  final String nome;
  final String papel;

  const UsuarioLogado({required this.id, required this.login, required this.nome, required this.papel});

  factory UsuarioLogado.fromJson(Map<String, dynamic> j) => UsuarioLogado(
        id: j['id'] as String,
        login: j['login'] as String,
        nome: j['nome'] as String,
        papel: j['papel'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'login': login, 'nome': nome, 'papel': papel};

  /// Quem lança e corrige entradas no estoque da fábrica.
  bool get podeLancar => papel == 'admin' || papel == 'fabrica';

  bool get podeConsultar => podeLancar || papel == 'leitura';
}

class LoginResultado {
  final String token;
  final DateTime expiraEm;
  final UsuarioLogado usuario;

  const LoginResultado({required this.token, required this.expiraEm, required this.usuario});

  factory LoginResultado.fromJson(Map<String, dynamic> j) => LoginResultado(
        token: j['token'] as String,
        expiraEm: _data(j['expiraEm']),
        usuario: UsuarioLogado.fromJson(j['usuario'] as Map<String, dynamic>),
      );
}

// --- Catálogo ---------------------------------------------------------------------------------

class LocalEstoque {
  final String id;
  final String nome;
  final String tipo;
  final String? temperatura;

  const LocalEstoque({required this.id, required this.nome, required this.tipo, this.temperatura});

  factory LocalEstoque.fromJson(Map<String, dynamic> j) => LocalEstoque(
        id: j['id'] as String,
        nome: j['nome'] as String,
        tipo: j['tipo'] as String,
        temperatura: j['temperatura'] as String?,
      );

  Map<String, dynamic> toJson() => {'id': id, 'nome': nome, 'tipo': tipo, 'temperatura': temperatura};
}

class Categoria {
  final String id;
  final String nome;

  const Categoria({required this.id, required this.nome});

  factory Categoria.fromJson(Map<String, dynamic> j) => Categoria(id: j['id'] as String, nome: j['nome'] as String);

  Map<String, dynamic> toJson() => {'id': id, 'nome': nome};
}

/// 1 [embalagem] = [qtdBase] unidades base do item (g, ml ou un).
class Embalagem {
  final String embalagem;
  final double qtdBase;

  const Embalagem({required this.embalagem, required this.qtdBase});

  factory Embalagem.fromJson(Map<String, dynamic> j) =>
      Embalagem(embalagem: j['embalagem'] as String, qtdBase: _numero(j['qtdBase']));

  Map<String, dynamic> toJson() => {'embalagem': embalagem, 'qtdBase': qtdBase};
}

class Variacao {
  final String id;
  final String rotulo;

  const Variacao({required this.id, required this.rotulo});

  factory Variacao.fromJson(Map<String, dynamic> j) => Variacao(id: j['id'] as String, rotulo: j['rotulo'] as String);

  Map<String, dynamic> toJson() => {'id': id, 'rotulo': rotulo};
}

class ItemCatalogo {
  final String id;
  final String nome;
  final String categoriaId;
  final String? subgrupo;

  /// g, ml ou un.
  final String unidadeBase;

  /// producao (feito na fábrica) ou terceiros (comprado).
  final String? nivel;
  final String? temperatura;
  final String? destino;
  final bool controlaValidade;

  /// Balde, cuba ou pote: uma linha por recipiente, com o peso real e o lote da etiqueta.
  final bool controlaRecipiente;
  final String? localPadraoId;
  final List<Embalagem> embalagens;
  final List<Variacao> variacoes;

  const ItemCatalogo({
    required this.id,
    required this.nome,
    required this.categoriaId,
    required this.unidadeBase,
    this.subgrupo,
    this.nivel,
    this.temperatura,
    this.destino,
    this.controlaValidade = false,
    this.controlaRecipiente = false,
    this.localPadraoId,
    this.embalagens = const [],
    this.variacoes = const [],
  });

  factory ItemCatalogo.fromJson(Map<String, dynamic> j) => ItemCatalogo(
        id: j['id'] as String,
        nome: j['nome'] as String,
        categoriaId: j['categoriaId'] as String,
        subgrupo: j['subgrupo'] as String?,
        unidadeBase: j['unidadeBase'] as String,
        nivel: j['nivel'] as String?,
        temperatura: j['temperatura'] as String?,
        destino: j['destino'] as String?,
        controlaValidade: (j['controlaValidade'] as bool?) ?? false,
        controlaRecipiente: (j['controlaRecipiente'] as bool?) ?? false,
        localPadraoId: j['localPadraoId'] as String?,
        embalagens:
            ((j['embalagens'] as List?) ?? const []).map((e) => Embalagem.fromJson(e as Map<String, dynamic>)).toList(),
        variacoes:
            ((j['variacoes'] as List?) ?? const []).map((e) => Variacao.fromJson(e as Map<String, dynamic>)).toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'categoriaId': categoriaId,
        'subgrupo': subgrupo,
        'unidadeBase': unidadeBase,
        'nivel': nivel,
        'temperatura': temperatura,
        'destino': destino,
        'controlaValidade': controlaValidade,
        'controlaRecipiente': controlaRecipiente,
        'localPadraoId': localPadraoId,
        'embalagens': embalagens.map((e) => e.toJson()).toList(),
        'variacoes': variacoes.map((e) => e.toJson()).toList(),
      };

  /// Origem sugerida na entrada: o que a fábrica produz entra como produção, o resto como compra.
  String get origemSugerida => nivel == 'producao' ? 'producao' : 'compra';

  /// Unidades que a API aceita para este item: a base, kg ou L (convertidos), e as embalagens
  /// cadastradas. Balde, cuba e pote só pesam: g e kg.
  List<String> get unidadesPermitidas {
    final base = switch (unidadeBase) {
      'g' => ['g', 'kg'],
      'ml' => ['ml', 'L'],
      _ => ['un'],
    };
    if (controlaRecipiente) return ['g', 'kg'];
    return [...base, ...embalagens.map((e) => e.embalagem)];
  }
}

class Catalogo {
  final List<LocalEstoque> locais;
  final List<Categoria> categorias;
  final List<ItemCatalogo> itens;

  const Catalogo({required this.locais, required this.categorias, required this.itens});

  factory Catalogo.fromJson(Map<String, dynamic> j) => Catalogo(
        locais: (j['locais'] as List).map((e) => LocalEstoque.fromJson(e as Map<String, dynamic>)).toList(),
        categorias: (j['categorias'] as List).map((e) => Categoria.fromJson(e as Map<String, dynamic>)).toList(),
        itens: (j['itens'] as List).map((e) => ItemCatalogo.fromJson(e as Map<String, dynamic>)).toList(),
      );

  Map<String, dynamic> toJson() => {
        'locais': locais.map((e) => e.toJson()).toList(),
        'categorias': categorias.map((e) => e.toJson()).toList(),
        'itens': itens.map((e) => e.toJson()).toList(),
      };

  ItemCatalogo? item(String id) {
    for (final i in itens) {
      if (i.id == id) return i;
    }
    return null;
  }

  LocalEstoque? local(String? id) {
    if (id == null) return null;
    for (final l in locais) {
      if (l.id == id) return l;
    }
    return null;
  }
}

// --- Entradas, histórico e saldo ---------------------------------------------------------------

/// criado, ja_registrado (reenvio) ou recusado (com o motivo em [erro]).
class ResultadoEntrada {
  final String id;
  final String status;
  final String? etiqueta;
  final double? qtdBase;
  final String? erro;

  const ResultadoEntrada({required this.id, required this.status, this.etiqueta, this.qtdBase, this.erro});

  factory ResultadoEntrada.fromJson(Map<String, dynamic> j) => ResultadoEntrada(
        id: j['id'] as String,
        status: j['status'] as String,
        etiqueta: j['etiqueta'] as String?,
        qtdBase: j['qtdBase'] == null ? null : _numero(j['qtdBase']),
        erro: j['erro'] as String?,
      );

  bool get registrada => status == 'criado' || status == 'ja_registrado';
}

class Movimento {
  final String id;
  final String tipo;
  final DateTime ocorridoEm;
  final String itemId;
  final String item;
  final String local;
  final String? variante;
  final double quantidade;
  final String unidade;
  final double qtdBase;
  final int? unidades;
  final String? origem;
  final String? lote;
  final String? etiqueta;
  final String? documento;
  final String? usuario;
  final String? estornaId;
  final bool estornado;
  final String? motivo;
  final String? autorizadoPor;

  /// Como o lançamento foi digitado na origem (planilha) e por que merece conferência. Só vêm
  /// preenchidos em dados importados com ressalva.
  final String? textoOriginal;
  final String? revisar;

  const Movimento({
    required this.id,
    required this.tipo,
    required this.ocorridoEm,
    required this.itemId,
    required this.item,
    required this.local,
    required this.quantidade,
    required this.unidade,
    required this.qtdBase,
    this.variante,
    this.unidades,
    this.origem,
    this.lote,
    this.etiqueta,
    this.documento,
    this.usuario,
    this.estornaId,
    this.estornado = false,
    this.motivo,
    this.autorizadoPor,
    this.textoOriginal,
    this.revisar,
  });

  factory Movimento.fromJson(Map<String, dynamic> j) => Movimento(
        id: j['id'] as String,
        tipo: j['tipo'] as String,
        ocorridoEm: _data(j['ocorridoEm']),
        itemId: j['itemId'] as String,
        item: j['item'] as String,
        local: j['local'] as String,
        variante: j['variante'] as String?,
        quantidade: _numero(j['quantidade']),
        unidade: j['unidade'] as String,
        qtdBase: _numero(j['qtdBase']),
        unidades: (j['unidades'] as num?)?.toInt(),
        origem: j['origem'] as String?,
        lote: j['lote'] as String?,
        etiqueta: j['etiqueta'] as String?,
        documento: j['documento'] as String?,
        usuario: j['usuario'] as String?,
        estornaId: j['estornaId'] as String?,
        estornado: (j['estornado'] as bool?) ?? false,
        motivo: j['motivo'] as String?,
        autorizadoPor: j['autorizadoPor'] as String?,
        textoOriginal: j['textoOriginal'] as String?,
        revisar: j['revisar'] as String?,
      );

  /// Só se estorna um lançamento comum que ainda não foi estornado. Ajuste e estorno ficam como estão.
  bool get podeEstornar => !estornado && estornaId == null && tipo != 'ajuste';

  bool get temDuvida => revisar != null && revisar!.trim().isNotEmpty;
}

class Saldo {
  final String localId;
  final String local;
  final String itemId;
  final String item;
  final String? variante;
  final String unidadeBase;
  final double saldoBase;
  final int saldoUnidades;

  /// Motivos (separados por "; ") pelos quais o saldo merece conferência: dado importado com ressalva,
  /// contagem sem valor, saldo negativo. Some quando entra uma contagem nova.
  final String? duvida;

  const Saldo({
    required this.localId,
    required this.local,
    required this.itemId,
    required this.item,
    required this.unidadeBase,
    required this.saldoBase,
    required this.saldoUnidades,
    this.variante,
    this.duvida,
  });

  factory Saldo.fromJson(Map<String, dynamic> j) => Saldo(
        localId: j['localId'] as String,
        local: j['local'] as String,
        itemId: j['itemId'] as String,
        item: j['item'] as String,
        variante: j['variante'] as String?,
        unidadeBase: j['unidadeBase'] as String,
        saldoBase: _numero(j['saldoBase']),
        saldoUnidades: (j['saldoUnidades'] as num).toInt(),
        duvida: j['duvida'] as String?,
      );

  bool get temDuvida => duvida != null && duvida!.trim().isNotEmpty;

  /// Cada motivo da dúvida em uma linha, para mostrar em lista.
  List<String> get motivosDaDuvida =>
      (duvida ?? '').split(';').map((m) => m.trim()).where((m) => m.isNotEmpty).toList();
}

/// Um balde, cuba ou pote em estoque, com o peso real dele.
class Recipiente {
  final String id;
  final String etiqueta;
  final String local;
  final String item;
  final double pesoBase;
  final String? lote;
  final DateTime? validade;
  final DateTime produzidoEm;

  const Recipiente({
    required this.id,
    required this.etiqueta,
    required this.local,
    required this.item,
    required this.pesoBase,
    required this.produzidoEm,
    this.lote,
    this.validade,
  });

  factory Recipiente.fromJson(Map<String, dynamic> j) => Recipiente(
        id: j['recipienteId'] as String,
        etiqueta: j['etiqueta'] as String,
        local: j['local'] as String,
        item: j['item'] as String,
        pesoBase: _numero(j['pesoBase']),
        lote: j['lote'] as String?,
        validade: j['validade'] == null ? null : DateTime.parse(j['validade'] as String),
        produzidoEm: _data(j['produzidoEm']),
      );
}
