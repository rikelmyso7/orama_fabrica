import 'package:flutter/material.dart';
import 'package:orama_fabrica2/auth/authStateSwitcher.dart';
import 'package:orama_fabrica2/pages/add_estoque_info.dart';
import 'package:orama_fabrica2/pages/login/login_page.dart';
import 'package:orama_fabrica2/pages/login/splash_page.dart';
import 'package:orama_fabrica2/pages/view_fabrica2_relatorio.dart';
import 'package:orama_fabrica2/pages/view_fabrica_relatorio.dart';

class RouteName {
  static const auth = '/';
  static const login = "/login";
  static const splash = "/splash";
  static const relatorios = "relatorios";
  static const relatorios2 = "relatorios2";
  static const home = "/home";
  static const add_estoque_info = "/add_esto que_info";
}

class Routes {
  Routes._();
  static final routes = {
    RouteName.auth: (BuildContext context) {
      return AuthStateSwitcher();
    },
    RouteName.splash: (BuildContext context) {
      return SplashScreen();
    },
    RouteName.login: (BuildContext context) {
      return LoginPage();
    },
    RouteName.home: (BuildContext context) {
      return ViewFabricaRelatorioPage();
    },
    RouteName.relatorios: (BuildContext context) {
      return ViewFabricaRelatorioPage2();
    },
    RouteName.add_estoque_info: (BuildContext context) {
      return AddEstoqueInfo(name: '',);
    },
  };
}
