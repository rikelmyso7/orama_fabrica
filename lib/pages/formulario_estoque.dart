import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:orama_fabrica2/others/insumos.dart';
import 'package:orama_fabrica2/routes/routes.dart';
import 'package:orama_fabrica2/utils/changeNotifier.dart';
import 'package:orama_fabrica2/utils/show_snackbar.dart';
import 'package:provider/provider.dart';

class FormularioEstoque extends StatefulWidget {
  final String nome;
  final List<String> estoquesSelecionados;
  final Map<String, dynamic>? reportData;
  final String? reportId;

  const FormularioEstoque({
    Key? key,
    required this.nome,
    required this.estoquesSelecionados,
    this.reportData,
    this.reportId,
  }) : super(key: key);

  @override
  State<FormularioEstoque> createState() => _FormularioEstoqueState();
}

class _FormularioEstoqueState extends State<FormularioEstoque>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final Map<String, TextEditingController> entradaControllers = {};
  final Map<String, TextEditingController> qtdAnteriorControllers = {};
  final Map<String, String> tipoSelecionado = {};
  bool isLoading = false;
  final FocusNode focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _initializeFields();
    _fetchPreviousQuantities();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  void _initializeFields() {
    if (widget.reportData != null) {
      _populateControllersFromReport(widget.reportData!);
    } else {
      _initializeEmptyFields();
    }
  }

  void _populateControllersFromReport(Map<String, dynamic> reportData) {
    final categorias = reportData['Categorias'] as List<dynamic>?;

    categorias?.forEach((category) {
      final categoryName = category['Categoria'];
      final itens = category['Itens'] as List<dynamic>;

      for (final item in itens) {
        final itemName = item['Item'];
        final key = _generateKey(categoryName, itemName);

        entradaControllers[key] = TextEditingController(
          text: item['Entrada']?.toString() ?? '', // Evita "null"
        );
        qtdAnteriorControllers[key] = TextEditingController(
          text: item['Qtd_anterior']?.toString() ?? '', // Evita "null"
        );
        tipoSelecionado[key] = item['tipo'] ?? "Un";
      }
    });
  }

  void _initializeEmptyFields() {
    for (final category in insumos.keys) {
      for (final item in insumos[category]!) {
        final itemName = item['nome'];
        final key = _generateKey(category, itemName);

        entradaControllers[key] =
            TextEditingController(text: ''); // Sempre vazio
        qtdAnteriorControllers[key] = TextEditingController(
          text: item['Qtd_anterior']?.toString() ?? '', // Se for null, será ''
        );
        tipoSelecionado[key] = "Un";
      }
    }
  }

  String _generateKey(String category, String itemName) {
    return (category == 'BALDES' || category == 'POTES' || category == 'CUBAS')
        ? '${category}_$itemName'
        : itemName;
  }

  Future<void> _saveToFirebase() async {
    setState(() => isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ShowSnackBar(context, 'Usuário não autenticado!', Colors.red);
      setState(() => isLoading = false);
      return;
    }

    final userId = user.uid;
    final reportId =
        widget.reportId ?? firestore.collection('fabrica_entradas').doc().id;
    final DateTime now = DateTime.now().toUtc().add(const Duration(hours: -3));
    final String formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(now);

    // Mapa para armazenar os itens organizados por categoria
    final Map<String, dynamic> itensOrganizados = {};

    for (final category in insumos.keys) {
      final List<Map<String, dynamic>> itensCategoria = [];

      for (final item in insumos[category]!) {
        final itemName = item['nome'];
        final key = _generateKey(category, itemName);
        final entrada = entradaControllers[key]?.text.trim() ?? '';

        // Só salva o item se `Entrada` tiver sido preenchido pelo usuário
        if (entrada.isNotEmpty) {
          final qtdAnterior = qtdAnteriorControllers[key]?.text.trim() ?? '';
          final tipoSelecionadoItem = tipoSelecionado[key] ?? "Un";

          itensCategoria.add({
            'Nome': itemName,
            'Entrada': entrada,
            'Qtd_anterior': qtdAnterior,
            'estoque_id': item['estoque_id'],
            'nomeclatura': item['nomeclatura'],
            'tipo': tipoSelecionadoItem,
          });
        }
      }

      if (itensCategoria.isNotEmpty) {
        itensOrganizados[category] = {'Itens': itensCategoria};
      }
    }

    // Só salva se houver pelo menos um item alterado
    if (itensOrganizados.isEmpty) {
      ShowSnackBar(context, 'Nenhum item foi alterado.', Colors.orange);
      setState(() => isLoading = false);
      return;
    }

    final report = {
      'ID': reportId,
      'Responsável': widget.nome,
      'Data': formattedDate,
      'Itens': itensOrganizados,
      'Estoques': widget.estoquesSelecionados,
    };

    try {
      await firestore
          .collection('users')
          .doc(userId)
          .collection('fabrica_entradas')
          .doc(reportId)
          .set(report);

      ShowSnackBar(context, 'Relatório salvo com sucesso!', Colors.green);
      Navigator.pushReplacementNamed(context, RouteName.home);
    } catch (e) {
      ShowSnackBar(context, 'Erro ao salvar Relatório!', Colors.red);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchPreviousQuantities() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userId = user.uid;
    final collectionRef = firestore
        .collection('users')
        .doc(userId)
        .collection('fabrica_entradas');

    // Obtém o relatório mais recente do Firestore
    final querySnapshot =
        await collectionRef.orderBy('Data', descending: true).limit(1).get();

    if (querySnapshot.docs.isNotEmpty) {
      final lastReport = querySnapshot.docs.first.data();
      final categorias = lastReport['Itens'] as Map<String, dynamic>?;

      categorias?.forEach((category, categoryData) {
        final itens = categoryData['Itens'] as List<dynamic>;

        for (final item in itens) {
          final itemName = item['Nome'];
          final key = _generateKey(category, itemName);

          setState(() {
            qtdAnteriorControllers[key] = TextEditingController(
              text: item['Entrada']?.toString() ?? '0',
            );
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filtra as categorias com base nos estoques selecionados
    final filteredCategories = insumos.keys.where((category) {
      final items = insumos[category]!;
      // Retorna verdadeiro se pelo menos um item da categoria estiver nos estoques selecionados
      return items.any(
          (item) => widget.estoquesSelecionados.contains(item['estoque_id']));
    }).toList();

    return ChangeNotifierProvider(
      create: (context) =>
          EstoqueController()..initializeFields(insumos, widget.reportData),
      child: Consumer<EstoqueController>(builder: (context, controller, child) {
        return DefaultTabController(
          length: filteredCategories.length,
          child: Scaffold(
            appBar: AppBar(
              iconTheme: const IconThemeData(color: Colors.white),
              title: const Text(
                'Entrada de Itens',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
              backgroundColor: const Color(0xff60C03D),
              actions: [
                isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : IconButton(
                        icon: const Icon(Icons.save),
                        onPressed: _saveToFirebase,
                      ),
              ],
              bottom: TabBar(
                labelColor: Colors.white,
                indicatorColor: Colors.amber,
                isScrollable: true,
                tabs: filteredCategories
                    .map((category) => Tab(text: category))
                    .toList(),
                onTap: (index) {
                  _removeFocus();
                },
              ),
            ),
            body: TabBarView(
              children: filteredCategories.map((category) {
                final items = List.from(insumos[category]!);
                items.sort((a, b) => a['nome'].compareTo(b['nome']));

                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final itemName = item['nome'];
                    final key = _generateKey(category, itemName);

                    return _buildItemCard(item, key);
                  },
                );
              }).toList(),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item, String key) {
    final itemName = item['nome'];

    const List<String> typeOptions = [
      'Balde',
      'Cuba',
      'Pote',
      'Un',
      'g',
      'Tubo',
      'Kg',
      'Fardo',
      'Caixa',
      'Sacos',
      'Litro',
      'Rolo',
    ];

    // Valor inicial do dropdown
    String dropdownValue = tipoSelecionado[key] ?? "Un";
    if (!typeOptions.contains(dropdownValue)) {
      dropdownValue = "Un"; // Valor padrão caso seja inválido
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              itemName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                        labelText: 'Entrada',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        suffixIcon: Icon(Icons.add_shopping_cart_rounded)),
                    keyboardType: TextInputType.number,
                    controller: entradaControllers[key],
                    onChanged: (value) {
                      setState(() {
                        entradaControllers[key]?.text = value.trim();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                // Dropdown para selecionar o tipo
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: dropdownValue,
                    decoration: InputDecoration(
                      labelText: 'Tipo',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: typeOptions
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          tipoSelecionado[key] = newValue;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                        labelText: 'Qtd Anterior',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[200],
                        suffixIcon: Icon(Icons.history_rounded)),
                    controller:
                        qtdAnteriorControllers[key] ?? TextEditingController(),
                    readOnly: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final controller in entradaControllers.values) {
      controller.dispose();
    }
    for (final controller in qtdAnteriorControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _removeFocus() {
    FocusScope.of(context).requestFocus(FocusNode());
  }
}
