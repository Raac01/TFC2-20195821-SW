import 'package:flutter/material.dart';

class SessionScreen extends StatelessWidget {
  const SessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sesión Activa')),
      body: const Center(child: Text('Datos en tiempo real...')),
    );
  }
}
