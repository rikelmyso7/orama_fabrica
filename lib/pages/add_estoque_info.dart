import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:orama_fabrica2/others/field_validators.dart';
import 'package:orama_fabrica2/pages/formulario_estoque.dart';
import 'package:orama_fabrica2/widgets/my_button.dart';
import 'package:orama_fabrica2/widgets/my_dropdown.dart';
import 'package:orama_fabrica2/widgets/my_textstyle.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

class AddEstoqueInfo extends StatefulWidget {
  final String name;

  AddEstoqueInfo({required this.name});

  @override
  _AddEstoqueInfoState createState() => _AddEstoqueInfoState();
}

class _AddEstoqueInfoState extends State<AddEstoqueInfo> {
  final formKey = GlobalKey<FormState>();
  final ValueNotifier<bool> isFormValid = ValueNotifier<bool>(false);

  final Map<String, bool> estoques = {
    "E1A": false,
    "E1B": false,
    "E1C": false,
  };

  final List<String> nome = ["Congelados", "Refrigerados", "Secos"];

  DateTime _date = DateTime.now();

  void _validateForm() {
    // Ativa o botão se pelo menos um estoque for selecionado
    isFormValid.value = estoques.values.any((isChecked) => isChecked);
  }

  @override
  void dispose() {
    isFormValid.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Nova Entrada",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        elevation: 4,
        backgroundColor: const Color(0xff60C03D),
        scrolledUnderElevation: 0,
      ),
      body: Center(
        child: SafeArea(
          child: Container(
            height: MediaQuery.of(context).size.height / 2,
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25.0),
                    child: TextFormField(
                      initialValue: widget.name,
                      readOnly: true,
                      decoration: InputDecoration(
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        fillColor: Colors.white,
                        filled: true,
                        labelText: "Responsável",
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Checkbox para selecionar estoques
                  Expanded(
                    child: ListView(
                      children: estoques.keys.map((estoque) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: CheckboxListTile(
                            title: Row(
                              children: [
                                Text(
                                    "$estoque - ${nome[estoques.keys.toList().indexOf(estoque)]}"),
                              ],
                            ),
                            value: estoques[estoque],
                            onChanged: (bool? value) {
                              setState(() {
                                estoques[estoque] = value ?? false;
                                _validateForm();
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // Botão de Próximo
                  ValueListenableBuilder<bool>(
                    valueListenable: isFormValid,
                    builder: (context, isValid, child) {
                      return MyButton(
                        buttonName: 'Próximo',
                        onTap: isValid
                            ? () {
                                final selectedEstoques = estoques.entries
                                    .where((entry) => entry.value)
                                    .map((entry) => entry.key)
                                    .toList();
                                print(selectedEstoques);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => FormularioEstoque(
                                      nome: widget.name,
                                      estoquesSelecionados: selectedEstoques,
                                    ),
                                  ),
                                );
                              }
                            : null,
                        enabled: isValid,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
