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

class ViewFabricaRelatorioPage2 extends StatefulWidget {
  @override
  _ViewFabricaRelatorioPage2State createState() =>
      _ViewFabricaRelatorioPage2State();
}

class _ViewFabricaRelatorioPage2State extends State<ViewFabricaRelatorioPage2> {
  bool isLoading = true;
  List<Map<String, dynamic>> reports = [];

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  String getUserName() {
    final userId = GetStorage().read('userId');
    if (userId == null) return "Usuário desconhecido";

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

  Future<void> _fetchReports() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userId = user.uid;
    List<Map<String, dynamic>> tempReports = [];

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('fabrica_entradas')
          .get();

      print("✅ ${querySnapshot.docs.length} relatórios encontrados.");

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        data['ID'] = doc.id;

        // Criar estrutura para agrupar itens por Estoque > Categoria
        Map<String, Map<String, List<dynamic>>> estoqueOrganizado = {
          'E1A - Congelados': {},
          'E1B - Refrigerados': {},
          'E1C - Secos': {}
        };

        if (data['Itens'] is Map) {
          data['Itens'].forEach((categoria, categoriaData) {
            if (categoriaData is Map && categoriaData['Itens'] is List) {
              for (var item in categoriaData['Itens']) {
                final String nomeclatura =
                    (item['nomeclatura'] ?? '').toUpperCase();

                String estoque;
                if (nomeclatura.contains('PPC') ||
                    nomeclatura.contains('PTC')) {
                  estoque = 'E1A - Congelados';
                } else if (nomeclatura.contains('PPR') ||
                    nomeclatura.contains('PTR')) {
                  estoque = 'E1B - Refrigerados';
                } else if (nomeclatura.contains('PPS') ||
                    nomeclatura.contains('PTS')) {
                  estoque = 'E1C - Secos';
                } else {
                  continue; // Se não pertence a nenhum estoque, pula o item
                }

                // Verifica se a categoria já existe no estoque
                if (!estoqueOrganizado[estoque]!.containsKey(categoria)) {
                  estoqueOrganizado[estoque]![categoria] = [];
                }

                // Adiciona o item na categoria correta dentro do estoque
                estoqueOrganizado[estoque]![categoria]!.add(item);
              }
            }
          });
        }

        tempReports.add({
          'ID': data['ID'],
          'Responsável': data['Responsável'],
          'Data': data['Data'],
          'Itens':
              estoqueOrganizado, // Agora o mapa tem Estoque > Categoria > Itens
        });

        print("📦 Relatório ${data['ID']} processado e armazenado.");
      }
    } catch (e) {
      print("❌ Erro ao buscar relatórios: $e");
    } finally {
      setState(() {
        reports = tempReports;
        isLoading = false;
      });
      print("🟢 Atualização concluída.");
    }
  }

  Future<void> _deleteReport(String reportId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userId = user.uid;

    bool confirmDelete = await showDialog<bool>(
          context: context,
          barrierDismissible:
              false, // Impede que o diálogo feche ao clicar fora
          builder: (context) => WillPopScope(
            onWillPop: () async =>
                false, // Impede fechamento ao pressionar voltar
            child: AlertDialog(
              title: Text("Excluir Relatório"),
              content: Text("Tem certeza que deseja excluir este relatório?"),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pop(false), // Cancela a exclusão
                  child: Text("Cancelar", style: TextStyle(color: Colors.red)),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pop(true), // Confirma a exclusão
                  child: Text("Excluir", style: TextStyle(color: Colors.green)),
                ),
              ],
            ),
          ),
        ) ??
        false; // Caso o usuário pressione voltar, assume "false" (não excluir)

    if (confirmDelete) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('fabrica_entradas')
            .doc(reportId)
            .delete();

        setState(() {
          reports.removeWhere((report) => report['ID'] == reportId);
        });

        ShowSnackBar(context, 'Relatório excluído com sucesso!', Colors.red);
      } catch (e) {
        ShowSnackBar(context, 'Erro ao excluir relatório!', Colors.red);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Relatórios Completo',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        iconTheme: IconThemeData(color: Colors.white),
        backgroundColor: const Color(0xff60C03D),
        actions: [
          IconButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.of(context).pushReplacementNamed(RouteName.login);
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      drawer: Menu(),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchReports,
              child: reports.isEmpty
                  ? const Center(child: Text("Nenhum relatório disponível"))
                  : ListView.builder(
                      itemCount: reports.length,
                      itemBuilder: (context, index) {
                        final sortedReports = List<Map<String, dynamic>>.from(
                            reports)
                          ..sort((a, b) {
                            final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
                            final dateA = a['Data'] != null
                                ? dateFormat.parse(a['Data'], true)
                                : DateTime(0);
                            final dateB = b['Data'] != null
                                ? dateFormat.parse(b['Data'], true)
                                : DateTime(0);
                            return dateB.compareTo(dateA); // Ordem decrescente
                          });

                        final report = sortedReports[index];

                        final dateString = report['Data'] ?? '';
                        DateTime? parsedDate;

                        try {
                          parsedDate =
                              DateFormat('dd/MM/yyyy HH:mm').parse(dateString);
                        } catch (e) {
                          print("Erro ao converter a data: $e");
                        }

                        final dayOfWeek = parsedDate != null
                            ? DateFormat('EEEE', 'pt_BR').format(parsedDate)
                            : '';

                        return Card(
                          margin: EdgeInsets.all(8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                          child: ExpansionTile(
                            title: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  report["Responsável"],
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                ),
                                Text(
                                  "Data: ${report["Data"]}",
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.grey[800]),
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
                            children: report["Itens"].entries.where(
                                (MapEntry<String, Map<String, List<dynamic>>>
                                    estoqueEntry) {
                              // Verifica se alguma categoria dentro do estoque tem itens
                              return estoqueEntry.value.values.any(
                                  (List<dynamic> itens) => itens.isNotEmpty);
                            }).map<Widget>(
                                (MapEntry<String, Map<String, List<dynamic>>>
                                    estoqueEntry) {
                              String estoque = estoqueEntry.key;
                              Map<String, List<dynamic>> categorias =
                                  estoqueEntry.value;

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0, vertical: 8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Divider(),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          estoque, // Exibir o estoque principal
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(right: 8),
                                          child: IconButton(
                                            icon: Icon(Icons.delete,
                                                color: Colors.red),
                                            onPressed: () =>
                                                _deleteReport(report['ID']),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: categorias.entries.where(
                                          (MapEntry<String, List<dynamic>>
                                              categoriaEntry) {
                                        // Filtra apenas categorias que têm itens
                                        return categoriaEntry.value.isNotEmpty;
                                      }).map((MapEntry<String, List<dynamic>>
                                          categoriaEntry) {
                                        String categoria = categoriaEntry.key;
                                        List<dynamic> itens =
                                            categoriaEntry.value;

                                        return Padding(
                                          padding: const EdgeInsets.only(
                                              left: 16, top: 4),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                categoria, // Exibe a categoria
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: itens.map((item) {
                                                  return Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        vertical: 4,
                                                        horizontal: 16),
                                                    child: RichText(
                                                      textAlign:
                                                          TextAlign.start,
                                                      text: TextSpan(
                                                        style: const TextStyle(
                                                            fontSize: 12,
                                                            color:
                                                                Colors.black),
                                                        children: [
                                                          TextSpan(
                                                            text:
                                                                "🟢 ${item['Nome']}\n",
                                                            style: const TextStyle(
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500),
                                                          ),
                                                          const TextSpan(
                                                            text:
                                                                "  ▪️​ Entrada no estoque: ",
                                                            style: TextStyle(
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .normal),
                                                          ),
                                                          TextSpan(
                                                            text:
                                                                "${item['Entrada']} ${item["tipo"]}\n",
                                                            style: const TextStyle(
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                height: 1.5),
                                                          ),
                                                          TextSpan(
                                                            text:
                                                                "  ▪️​ ${item['nomeclatura']} ▪️​ ${item['estoque_id']}",
                                                            style: const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w400,
                                                                height: 1.5),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                }).toList(),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xff60C03D),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Adicionar', style: TextStyle(color: Colors.white)),
        onPressed: () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => AddEstoqueInfo(name: getUserName())));
        },
      ),
    );
  }
}
