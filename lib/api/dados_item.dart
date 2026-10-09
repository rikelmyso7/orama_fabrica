import 'models.dart';

/// O que o administrador preenche para criar ou editar um item do catálogo.
class DadosItem {
  final String nome;
  final String categoriaId;
  final String? subgrupo;
  final String? tamanho;
  final String unidadeBase;
  final String? nivel;
  final String? temperatura;
  final String? destino;
  final bool controlaValidade;
  final bool controlaRecipiente;
  final List<Embalagem> embalagens;

  const DadosItem({
    required this.nome,
    required this.categoriaId,
    required this.unidadeBase,
    this.subgrupo,
    this.tamanho,
    this.nivel,
    this.temperatura,
    this.destino,
    this.controlaValidade = false,
    this.controlaRecipiente = false,
    this.embalagens = const [],
  });

  Map<String, dynamic> _comuns() => {
        'nome': nome.trim(),
        'categoriaId': categoriaId,
        'subgrupo': subgrupo,
        'tamanho': tamanho,
        'nivel': nivel,
        'temperatura': temperatura,
        'destino': destino,
        'controlaValidade': controlaValidade,
        'controlaRecipiente': controlaRecipiente,
        'embalagens': embalagens.map((e) => e.toJson()).toList(),
      };

  /// Criação: a unidade base entra aqui e não muda depois.
  Map<String, dynamic> paraCriar() =>
      {..._comuns(), 'unidadeBase': unidadeBase};

  /// Edição: [ativo] falso tira o item de uso (a API recusa se ainda houver saldo).
  Map<String, dynamic> paraEditar({required bool ativo}) =>
      {..._comuns(), 'ativo': ativo};
}
