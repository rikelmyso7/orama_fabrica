import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:orama_fabrica2/others/field_validators.dart';
import 'package:orama_fabrica2/routes/routes.dart';
import 'package:orama_fabrica2/utils/exit_dialog_utils.dart';
import 'package:orama_fabrica2/widgets/my_textfield.dart';

class LoginPage extends StatefulWidget {
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  bool obscurePassword = true;
  bool isLoading = false;

  void _showSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showErrorDialog(String message) {
    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Erro'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
              },
              child: Text('Ok'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _login() async {
    if (!formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      isLoading = true;
    });
    try {
      final authResult = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      print('Login realizado com sucesso!');
      final userId = authResult.user!.uid;
      if (userId != null) {
        await GetStorage().write('userId', userId);
      }

      // Verifica se o documento do usuário já existe no Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        // Cria o documento se ele não existir
        await FirebaseFirestore.instance.collection('users').doc(userId).set({
          'role': 'user', // ou outro valor padrão que faça sentido
          'createdAt': FieldValue.serverTimestamp(),
          'email': _emailController.text,
        });
        print("Documento de usuário criado no Firestore.");
      }

      // Após a verificação, obtenha os dados do Firestore novamente
      final userData = (await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get())
          .data();

      if (userData != null && userData['role'] == 'user') {
        Navigator.of(context).pushReplacementNamed(RouteName.relatorios);
      } else {
        _showErrorDialog('Usuário sem permissão.');
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        _showSnackbar('Email não cadastrado');
      } else {
        _showSnackbar('Erro: ${e.message}');
      }
    } catch (e) {
      _showSnackbar('Ocorreu um erro. Tente novamente.');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();

    // Configura a cor da barra de status
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor:
          const Color(0xff60C03D), // Define a cor da barra de status
      statusBarIconBrightness: Brightness.light, // Ícones brancos na barra
    ));
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final bool shouldPop =
            await DialogUtils.showBackDialog(context) ?? false;
        return shouldPop;
      },
      child: Scaffold(
        body: SizedBox.expand(
          child: Center(
            child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                color: Color(0xff60C03D),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.5), // Cor da sombra
                    spreadRadius: 5, // Espalhamento
                    blurRadius: 12, // Borrão
                    offset: Offset(0, 3), // Deslocamento (x, y)
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Form(
                    key: formKey,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          Text(
                            "Fazer Login",
                            style: GoogleFonts.nunito(
                                textStyle: TextStyle(
                                    fontSize: 40, fontWeight: FontWeight.w500),
                                color: Colors.white),
                          ),
                          SizedBox(
                            height: 10,
                          ),
                          MyTextField(
                            controller: _emailController,
                            hintText: 'Email',
                            validator: FieldValidators.validateEmail,
                            prefixicon: Icon(Icons.email),
                          ),
                          MyTextField(
                            controller: _passwordController,
                            hintText: 'Senha',
                            obscureText: obscurePassword,
                            validator: FieldValidators.validatePassword,
                            prefixicon: Icon(Icons.lock),
                            icon: Padding(
                              padding: const EdgeInsets.only(right: 5),
                              child: IconButton(
                                onPressed: () {
                                  setState(() {
                                    obscurePassword = !obscurePassword;
                                  });
                                },
                                icon: Icon(
                                  obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 20,
                          ),
                          if (isLoading)
                            CircularProgressIndicator()
                          else
                            ElevatedButton(
                              onPressed: _login,
                              child: Text(
                                'Login',
                                style: TextStyle(color: Color(0xff60C03D)),
                              ),
                            ),
                        ],
                      ),
                    ),
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
