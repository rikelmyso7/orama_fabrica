import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../auth/auth_store.dart';
import '../widgets/my_textfield.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _login = TextEditingController();
  final _senha = TextEditingController();
  final _form = GlobalKey<FormState>();

  bool _ocultarSenha = true;
  bool _carregando = false;
  String? _erro;

  @override
  void dispose() {
    _login.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_form.currentState!.validate()) return;
    final auth = context.read<AuthStore>();
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      await auth.entrar(_login.text, _senha.text);
      // sucesso: o AuthGate troca de tela sozinho
    } on ApiException catch (e) {
      _erro = e.mensagem;
    } on SemConexaoException catch (e) {
      _erro = e.mensagem;
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  String? _obrigatorio(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff60C03D),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Orama Fábrica',
                    style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 24),
                  MyTextField(
                    controller: _login,
                    hintText: 'Login',
                    validator: _obrigatorio,
                    prefixicon: const Icon(Icons.person),
                  ),
                  MyTextField(
                    controller: _senha,
                    hintText: 'Senha',
                    obscureText: _ocultarSenha,
                    validator: _obrigatorio,
                    prefixicon: const Icon(Icons.lock),
                    icon: IconButton(
                      tooltip:
                          _ocultarSenha ? 'Mostrar senha' : 'Esconder senha',
                      onPressed: () =>
                          setState(() => _ocultarSenha = !_ocultarSenha),
                      icon: Icon(
                          _ocultarSenha
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.grey),
                    ),
                  ),
                  if (_erro != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 25, vertical: 8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(_erro!,
                            style: TextStyle(color: Colors.red.shade900)),
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (_carregando)
                    const CircularProgressIndicator(color: Colors.white)
                  else
                    ElevatedButton(
                      onPressed: _entrar,
                      child: const Text('Entrar',
                          style: TextStyle(color: Color(0xff60C03D))),
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
