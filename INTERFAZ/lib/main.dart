import 'package:flutter/material.dart';
import 'utils/colors.dart';
import 'screens/start_screen.dart';
import 'screens/home_screen.dart';
import 'screens/session_screen.dart';
import 'screens/history_screen.dart';
import 'screens/config_screen.dart';
import 'screens/training_screen.dart';
import 'dart:convert';
import 'services/database.dart';
import 'models/session.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();   // DB
  runApp(const AsistenteApp());
}

class AsistenteApp extends StatelessWidget {
  const AsistenteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Asistente Cognitivo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const StartScreen(),
        '/training': (context) => const TrainingScreen(),
        '/home': (context) => const HomeScreen(),
        '/session': (context) => const SessionScreen(),
        '/history': (context) => const HistoryScreen(),
        '/config': (context) => const ConfigScreen(),
      },
    );
  }
}
