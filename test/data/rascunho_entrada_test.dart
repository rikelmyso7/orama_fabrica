import 'package:flutter_test/flutter_test.dart';
import 'package:orama_fabrica2/api/models.dart';
import 'package:orama_fabrica2/data/rascunho_entrada.dart';

ItemCatalogo get balde => const ItemCatalogo(
      id: 'it-balde', nome: 'COCADA', categoriaId: 'c', unidadeBase: 'g', nivel: 'producao',
      controlaRecipiente: true, controlaValidade: true,
    );

ItemCatalogo get cookie => const ItemCatalogo(id: 'it-cookie', nome: 'BROWNIE', categoriaId: 'c', unidadeBase: 'un', nivel: 'producao');

ItemCatalogo get castanha => const ItemCatalogo(
      id: 'it-castanha', nome: 'CASTANHA', categoriaId: 'c', unidadeBase: 'g', nivel: 'terceiros',
      embalagens: [Embalagem(embalagem: 'cx', qtdBase: 1000)],
    );

void main() {
  final agora = DateTime(2026, 10, 4, 15, 30);
  late RascunhoEntrada rascunho;

  setUp(() => rascunho = RascunhoEntrada(usuarioId: 'u1', agora: () => agora));

  test('item comum vira uma linha com id próprio e a hora atual', () {
    rascunho.adicionarComum(item: cookie, quantidade: 12, unidade: 'un', origem: 'producao');

    final l = rascunho.linhas.single;
    expect((l.itemId, l.quantidade, l.unidade, l.unidades, l.origem, l.ocorridoEm), ('it-cookie', '12', 'un', null, 'producao', agora));
    expect(l.id, isNotEmpty);
    expect(l.usuarioId, 'u1');
  });

  test('cada recipiente vira uma linha, com o mesmo lote e dia e o peso real de cada um', () {
    rascunho.adicionarRecipientes(
      item: balde,
      pesos: const [PesoDigitado(4100, 'g'), PesoDigitado(3.85, 'kg'), PesoDigitado(4.2, 'kg')],
      lote: ' L7 ',
      dia: DateTime(2026, 10, 4),
      origem: 'producao',
      validade: DateTime(2027, 4, 1),
    );

    final l = rascunho.linhas;
    expect(l.map((e) => (e.quantidade, e.unidade)), [('4100', 'g'), ('3.85', 'kg'), ('4.2', 'kg')]);
    expect(l.every((e) => e.unidades == 1 && e.lote == 'L7' && e.validade == DateTime(2027, 4, 1)), isTrue);
    expect(l.map((e) => e.id).toSet(), hasLength(3), reason: 'ids diferentes por recipiente');
  });

  test('dia de hoje usa a hora atual; outro dia usa o meio-dia daquele dia', () {
    rascunho.adicionarRecipientes(item: balde, pesos: const [PesoDigitado(4000, 'g')], lote: 'L1', dia: DateTime(2026, 10, 4), origem: 'producao');
    rascunho.adicionarRecipientes(item: balde, pesos: const [PesoDigitado(4000, 'g')], lote: 'L1', dia: DateTime(2026, 10, 2), origem: 'producao');

    expect(rascunho.linhas[0].ocorridoEm, agora);
    expect(rascunho.linhas[1].ocorridoEm, DateTime(2026, 10, 2, 12));
  });

  test('recipiente sem lote é recusado', () {
    expect(
      () => rascunho.adicionarRecipientes(item: balde, pesos: const [PesoDigitado(4000, 'g')], lote: '  ', dia: DateTime(2026, 10, 4), origem: 'producao'),
      throwsArgumentError,
    );
    expect(rascunho.total, 0);
  });

  test('contagem por item, remover e concluir', () {
    rascunho.adicionarComum(item: cookie, quantidade: 1, unidade: 'un', origem: 'producao');
    rascunho.adicionarComum(item: cookie, quantidade: 2, unidade: 'un', origem: 'producao');
    rascunho.adicionarComum(item: castanha, quantidade: 1, unidade: 'cx', origem: 'compra');
    expect((rascunho.total, rascunho.totalDoItem('it-cookie'), rascunho.totalDoItem('it-castanha')), (3, 2, 1));

    rascunho.remover(rascunho.linhas.first.id);
    expect(rascunho.totalDoItem('it-cookie'), 1);

    final entregues = rascunho.concluir();
    expect(entregues, hasLength(2));
    expect(rascunho.total, 0);
  });

  test('notifica quem escuta', () {
    var avisos = 0;
    rascunho.addListener(() => avisos++);

    rascunho.adicionarComum(item: cookie, quantidade: 1, unidade: 'un', origem: 'producao');
    rascunho.remover(rascunho.linhas.single.id);

    expect(avisos, 2);
  });

  test('origem sugerida e unidades permitidas por tipo de item', () {
    expect(balde.origemSugerida, 'producao');
    expect(castanha.origemSugerida, 'compra');
    expect(balde.unidadesPermitidas, ['g', 'kg']);
    expect(cookie.unidadesPermitidas, ['un']);
    expect(castanha.unidadesPermitidas, ['g', 'kg', 'cx']);
    expect(const ItemCatalogo(id: 'x', nome: 'LEITE', categoriaId: 'c', unidadeBase: 'ml').unidadesPermitidas, ['ml', 'L']);
  });
}
