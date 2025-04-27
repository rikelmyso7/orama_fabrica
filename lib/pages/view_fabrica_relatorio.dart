import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:orama_fabrica2/pages/add_estoque_info.dart';
import 'package:orama_fabrica2/routes/routes.dart';
import 'package:orama_fabrica2/utils/exit_dialog_utils.dart';
import 'package:orama_fabrica2/utils/show_snackbar.dart';
import 'package:orama_fabrica2/widgets/my_menu.dart';

class ViewFabricaRelatorioPage extends StatefulWidget {
  @override
  _ViewFabricaRelatorioPageState createState() =>
      _ViewFabricaRelatorioPageState();
}

class _ViewFabricaRelatorioPageState extends State<ViewFabricaRelatorioPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  List<String> estoques = [
    "E1A - CONGELADOS",
    "E1B - REFRIGERADOS",
    "E1C - SECOS"
  ];

  Map<String, List<Map<String, dynamic>>> reportsByStock = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: estoques.length,
      vsync: this,
    );
    _fetchReports();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String getUserName() {
    final userId = GetStorage().read('userId');
    if (userId == null) {
      return "Usuário desconhecido";
    }
    switch (userId) {
      case "eAU6EyVrH0apLBsmArTesS10dpl1":
        return "Betânia";
      case "ONq5kajhKSZyESqnEa2bnriBQ6K2":
        return "Leticia";
      case "CLM1MkoAQOQTaNtpID9yy9tNcK73":
        return "Evelyn";
      default:
        return "Usuário desconhecido";
    }
  }

  Future<void> validateAndSyncUserId() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await GetStorage().write('userId', currentUser.uid);
    } else {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(RouteName.login);
      }
    }
  }

  Future<void> _fetchReports() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userId = user.uid;
    Map<String, List<Map<String, dynamic>>> tempReportsByStock = {
      'E1A': [],
      'E1B': [],
      'E1C': []
    };

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('fabrica_entradas')
          .get();

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        data['ID'] = doc.id;

        // Criando um mapa temporário para organizar os estoques
        Map<String, List<dynamic>> estoqueOrganizado = {
          'E1A': [],
          'E1B': [],
          'E1C': []
        };

        if (data['Itens'] is Map) {
          data['Itens'].forEach((categoria, categoriaData) {
            if (categoriaData is Map && categoriaData['Itens'] is List) {
              List<dynamic> itensLista = categoriaData['Itens'];

              for (var item in itensLista) {
                final String nomeclatura =
                    (item['nomeclatura'] ?? '').toUpperCase();

                // Classificação por nomeclatura
                if (nomeclatura.contains('PPC') ||
                    nomeclatura.contains('PTC')) {
                  estoqueOrganizado['E1A']!.add(item);
                  print(
                      "🟢 Item '${item['Nome']}' classificado como E1A (Congelados)");
                } else if (nomeclatura.contains('PPR') ||
                    nomeclatura.contains('PTR')) {
                  estoqueOrganizado['E1B']!.add(item);
                  print(
                      "🟡 Item '${item['Nome']}' classificado como E1B (Refrigerados)");
                } else if (nomeclatura.contains('PPS') ||
                    nomeclatura.contains('PTS')) {
                  estoqueOrganizado['E1C']!.add(item);
                  print(
                      "🔵 Item '${item['Nome']}' classificado como E1C (Secos)");
                } else {
                  print(
                      "⚠️ Item '${item['Nome']}' não classificado em nenhum estoque.");
                }
              }
            }
          });
        }

        // Adiciona o relatório a cada estoque correspondente
        estoqueOrganizado.forEach((estoque, itens) {
          if (itens.isNotEmpty) {
            tempReportsByStock[estoque]!.add({
              'ID': data['ID'],
              'Responsável': data['Responsável'],
              'Data': data['Data'],
              'Itens': {'Itens': itens}, // Adiciona apenas os itens filtrados
            });
            print(
                "✅ Relatório ID: ${data['ID']} adicionado ao estoque $estoque.");
          }
        });
      }
    } catch (e) {
      print("Erro ao buscar relatórios: $e");
    } finally {
      setState(() {
        reportsByStock = tempReportsByStock;
        isLoading = false;
      });
    }
  }

  Future<void> _deleteReport(String estoque, String reportId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userId = user.uid;

    // Exibir diálogo de confirmação antes de deletar
    bool confirmDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Excluir Relatório"),
        content: Text("Tem certeza que deseja excluir este relatório?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text("Excluir", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmDelete == true) {
      try {
        // Deletar do Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('fabrica_entradas')
            .doc(reportId)
            .delete();

        // Remover localmente da lista e atualizar a tela
        setState(() {
          reportsByStock[estoque]
              ?.removeWhere((report) => report['ID'] == reportId);
        });

        ShowSnackBar(context, 'Relatório excluido com sucesso!', Colors.red);
      } catch (e) {
        ShowSnackBar(context, 'Erro ao excluir relatório!', Colors.red);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) {
          return;
        }
        final bool shouldPop =
            await DialogUtils.showBackDialog(context) ?? false;
        if (context.mounted && shouldPop) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Relatórios Especifico',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
          ),
          iconTheme: IconThemeData(color: Colors.white),
          backgroundColor: const Color(0xff60C03D),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: IconButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  Navigator.of(context).pushReplacementNamed(RouteName.login);
                },
                icon: const Icon(Icons.logout),
              ),
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            indicatorColor: Colors.amber,
            tabs: estoques.map((store) => Tab(text: store)).toList(),
          ),
        ),
        drawer: Menu(),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: estoques.map((estoqueCompleto) {
                  String estoqueCodigo = estoqueCompleto.split(" - ")[0];

                  final reports = reportsByStock[estoqueCodigo] ?? [];

                  return RefreshIndicator(
                    onRefresh: _fetchReports,
                    child: reports.isEmpty
                        ? const Center(
                            child: Text("Nenhum relatório disponível"))
                        : ListView.builder(
                            itemCount: reports.length,
                            itemBuilder: (context, index) {
                              final sortedReports =
                                  List<Map<String, dynamic>>.from(reports)
                                    ..sort((a, b) {
                                      final dateFormat =
                                          DateFormat('dd/MM/yyyy HH:mm');
                                      final dateA = a['Data'] != null
                                          ? dateFormat.parse(a['Data'], true)
                                          : DateTime(0);
                                      final dateB = b['Data'] != null
                                          ? dateFormat.parse(b['Data'], true)
                                          : DateTime(0);
                                      return dateB.compareTo(
                                          dateA); // Ordem decrescente
                                    });

                              final report = sortedReports[index];

                              final dateString = report['Data'] ?? '';
                              DateTime? parsedDate;

                              try {
                                parsedDate = DateFormat('dd/MM/yyyy HH:mm')
                                    .parse(dateString);
                              } catch (e) {
                                print("Erro ao converter a data: $e");
                              }

                              final dayOfWeek = parsedDate != null
                                  ? DateFormat('EEEE', 'pt_BR')
                                      .format(parsedDate)
                                  : '';

                              return Card(
                                margin: EdgeInsets.all(8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                                child: ExpansionTile(
                                  title: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        report["Responsável"],
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        "Estoque: $estoqueCodigo",
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[800]),
                                      ),
                                      Text(
                                        "Data: ${report["Data"]}",
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[800]),
                                      ),
                                      Text(
                                        "Dia da Semana: $dayOfWeek",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w400,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16.0, vertical: 8.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (report["Itens"] != null &&
                                              report["Itens"].isNotEmpty) ...[
                                            Divider(),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  "Lista de Itens:",
                                                  style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          right: 8),
                                                  child: IconButton(
                                                    icon: Icon(Icons.delete,
                                                        color: Colors.red),
                                                    onPressed: () =>
                                                        _deleteReport(
                                                            estoqueCodigo,
                                                            report['ID']),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            ...report["Itens"]
                                                .entries
                                                .map((entry) {
                                              String categoria = entry.key;
                                              List<dynamic> itens = entry.value;

                                              return Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    "$categoria:",
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600),
                                                  ),
                                                  Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: itens.map((item) {
                                                      return Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 4),
                                                          child: RichText(
                                                            textAlign:
                                                                TextAlign.start,
                                                            text: TextSpan(
                                                              style: const TextStyle(
                                                                  fontSize: 12,
                                                                  color: Colors
                                                                      .black), // Estilo padrão
                                                              children: [
                                                                TextSpan(
                                                                  text:
                                                                      "🟢 ${item['Nome']}\n",
                                                                  style: const TextStyle(
                                                                      fontSize:
                                                                          12,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w500), // Nome em negrito
                                                                ),
                                                                const TextSpan(
                                                                  text:
                                                                      "  ▪️​ Entrada no estoque: ",
                                                                  style: TextStyle(
                                                                      fontSize:
                                                                          12,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .normal),
                                                                ),
                                                                TextSpan(
                                                                  text:
                                                                      "${item['Entrada']} ${item["tipo"]}\n",
                                                                  style: const TextStyle(
                                                                      fontSize:
                                                                          12,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      height:
                                                                          1.5),
                                                                ),
                                                                TextSpan(
                                                                  text:
                                                                      "  ▪️​ ${item['nomeclatura']} ▪️​ ${item['estoque_id']}",
                                                                  style: const TextStyle(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w400,
                                                                      height:
                                                                          1.5),
                                                                ),
                                                              ],
                                                            ),
                                                          ));
                                                    }).toList(),
                                                  ),
                                                  const SizedBox(height: 8),
                                                ],
                                              );
                                            }).toList(),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  );
                }).toList(),
              ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: const Color(0xff60C03D),
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Adicionar', style: TextStyle(color: Colors.white)),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddEstoqueInfo(name: getUserName()),
              ),
            );
          },
        ),
      ),
    );
  }
}
