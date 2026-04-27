// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme/grc_theme.dart';
import 'screens/login_screen.dart';

import 'package:flutter_native_splash/flutter_native_splash.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const TeacherEvalApp());
  
  // Enforce a 1.5-second minimum display time for the splash screen
  await Future.delayed(const Duration(milliseconds: 1500));
  FlutterNativeSplash.remove();
}

class TeacherEvalApp extends StatelessWidget {
  const TeacherEvalApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EvalPro - GRC',
      theme: GrcTheme.theme,
      home: const LoginScreen(),
    );
  }
}