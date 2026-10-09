import 'api_client.dart';
import 'dados_item.dart';
import 'models.dart';

/// Os endpoints da orama_api que o app da fábrica usa, com tipos.
class OramaApi {
  OramaApi(this._client);

  final ApiClient _client;

  Future<LoginResultado> login(String login, String senha) async {
    final resposta = await _client.post(
      '/auth/login',
      corpo: {'login': login.trim(), 'senha': senha},
      autenticado: false,
    );
    return LoginResultado.fromJson(resposta as Map<String, dynamic>);
  }

  Future<Catalogo> catalogo() async =>
      Catalogo.fromJson(await _client.get('/catalogo') as Map<String, dynamic>);

  /// Envia entradas. Cada item tem o seu id (gerado no aparelho), então reenviar não duplica.
  Future<List<ResultadoEntrada>> enviarEntradas(
      List<Map<String, dynamic>> itens,
      {String? loteEnvioId}) async {
    final resposta = await _client.post('/entradas', corpo: {
      if (loteEnvioId != null) 'loteEnvioId': loteEnvioId,
      'itens': itens,
    }) as Map<String, dynamic>;
    return (resposta['resultados'] as List)
        .map((e) => ResultadoEntrada.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<String> loteSugerido({DateTime? data}) async {
    final resposta = await _client.get('/operacoes/lote-sugerido', query: {
      if (data != null) 'data': _dia(data),
    }) as Map<String, dynamic>;
    return resposta['lote'] as String;
  }

  /// Envia uma operação completa. Consumos e entradas são gravados na mesma transação pela API.
  Future<OperacaoCriada> enviarOperacao(Map<String, dynamic> operacao) async {
    final resposta = await _client.post('/operacoes', corpo: operacao)
        as Map<String, dynamic>;
    return OperacaoCriada.fromJson(resposta);
  }

  /// Histórico, do mais recente para o mais antigo. [de] e [ate] são dias do calendário, ambos incluídos.
  Future<List<Movimento>> movimentos({
    DateTime? de,
    DateTime? ate,
    String? localId,
    String? itemId,
    int limite = 200,
  }) async {
    final resposta = await _client.get('/movimentos', query: {
      if (de != null) 'de': _dia(de),
      if (ate != null) 'ate': _dia(ate),
      if (localId != null) 'localId': localId,
      if (itemId != null) 'itemId': itemId,
      'limite': '$limite',
    }) as List;
    return resposta
        .map((e) => Movimento.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<OperacaoDetalhe> operacao(String id) async {
    final resposta =
        await _client.get('/operacoes/$id') as Map<String, dynamic>;
    return OperacaoDetalhe.fromJson(resposta);
  }

  Future<List<LoteOrigem>> origemDoLote(String lote) async {
    final resposta = await _client.get('/lotes/$lote/origem') as List;
    return resposta
        .map((e) => LoteOrigem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Saldo>> saldo() async {
    final resposta = await _client.get('/saldo') as List;
    return resposta
        .map((e) => Saldo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Recipiente>> recipientes(String itemId) async {
    final resposta =
        await _client.get('/recipientes', query: {'itemId': itemId}) as List;
    return resposta
        .map((e) => Recipiente.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Estorna um lançamento. [senha] é a senha de administrador, conferida no servidor.
  Future<void> estornar({
    required String movimentoId,
    required String novoId,
    required String motivo,
    required String senha,
  }) async {
    await _client.post('/movimentos/$movimentoId/estorno',
        corpo: {'novoId': novoId, 'motivo': motivo, 'senha': senha});
  }

  // --- Cadastro do catálogo (só administrador) ----------------------------------------------

  Future<String> criarCategoria(String nome) async {
    final r =
        await _client.post('/catalogo/categorias', corpo: {'nome': nome.trim()})
            as Map<String, dynamic>;
    return r['id'] as String;
  }

  Future<void> editarCategoria(String id,
      {required String nome, required bool ativo}) async {
    await _client.put('/catalogo/categorias/$id',
        corpo: {'nome': nome.trim(), 'ativo': ativo});
  }

  Future<String> criarItem(DadosItem dados) async {
    final r = await _client.post('/catalogo/itens', corpo: dados.paraCriar())
        as Map<String, dynamic>;
    return r['id'] as String;
  }

  Future<void> editarItem(String id, DadosItem dados,
      {bool ativo = true}) async {
    await _client.put('/catalogo/itens/$id',
        corpo: dados.paraEditar(ativo: ativo));
  }

  static String _dia(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
