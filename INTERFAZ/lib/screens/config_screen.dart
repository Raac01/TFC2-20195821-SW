import 'package:flutter/material.dart';

class ConfigScreen extends StatelessWidget {
  const ConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración de Sesión')),
      body: const Center(child: Text('Parámetros de configuración')),
    );
  }
}
