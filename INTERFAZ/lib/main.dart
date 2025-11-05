import 'package:flutter/material.dart';
import 'screens/start_screen.dart';
import 'screens/training_screen.dart';
import 'screens/home_screen.dart';
import 'screens/session_screen.dart';
import 'screens/history_screen.dart';
import 'screens/config_screen.dart';

void main() {
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
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
