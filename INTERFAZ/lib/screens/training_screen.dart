import 'package:flutter/material.dart';

class TrainingScreen extends StatelessWidget {
  const TrainingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Entrenamiento')),
      body: const Center(child: Text('Pantalla de Entrenamiento')),
    );
  }
}
