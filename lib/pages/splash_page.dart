import 'package:flutter/material.dart';

/// Tela mostrada enquanto o app confere se já existe uma sessão salva.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: ColoredBox(
          color: const Color(0xff006764),
          child: Center(child: Image.asset('lib/assets/splashscreen.png')),
        ),
      ),
    );
  }
}
