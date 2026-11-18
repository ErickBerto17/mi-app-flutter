import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';

void main() async {
  // 1. Aseguramos que Flutter esté listo y mantenemos la splash nativa
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // 2. Inicializamos Firebase con la configuración de tu proyecto
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 3. Arrancamos la app
  runApp(const MiAsistApp());
}

class MiAsistApp extends StatelessWidget {
  const MiAsistApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AsistApp',
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}