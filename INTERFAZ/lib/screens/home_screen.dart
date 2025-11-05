import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Menú Principal')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/session'),
              child: const Text('Iniciar Sesión'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/history'),
              child: const Text('Ver Historial'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/config'),
              child: const Text('Configuración'),
            ),
          ],
        ),
      ),
    );
  }
}
