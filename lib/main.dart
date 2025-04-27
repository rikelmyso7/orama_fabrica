import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:orama_fabrica2/routes/routes.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_api_availability/google_api_availability.dart';
import 'auth/firebase_options.dart';

Future<void> checkAndUpdateProvider() async {
  final googleApiAvailability = GoogleApiAvailability.instance;

  // Verifica se o Google Play Services está disponível
  GooglePlayServicesAvailability availability = await googleApiAvailability.checkGooglePlayServicesAvailability();
  if (availability == GooglePlayServicesAvailability.success) {
    print('Google Play Services está disponível.');
    try {
      await googleApiAvailability.makeGooglePlayServicesAvailable();
      print('Provider atualizado com sucesso!');
    } catch (e) {
      print('Erro ao atualizar o Provider: $e');
    }
  } else {
    print('Google Play Services não está disponível: $availability');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);
  // await GetStorage.init();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Relatórios Fábrica',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      routes: Routes.routes,
      initialRoute: RouteName.splash,
    );
  }
}
