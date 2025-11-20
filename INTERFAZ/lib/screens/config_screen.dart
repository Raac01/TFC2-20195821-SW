import 'package:flutter/material.dart';
import '../utils/colors.dart';
import '../utils/styles.dart';
import '../services/prefs.dart';
import 'training_screen.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final SettingsService settings = SettingsService();
  int sessionMinutes = 25;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    sessionMinutes = await settings.getSessionDuration();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Configuración",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Ajuste de tiempo de sesión

            Text("Tiempo de sesión", style: AppStyles.heading1),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ],
              ),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Duración (minutos)", style: AppStyles.heading2),
                  const SizedBox(height: 12),

                  Slider(
                    min: 5,
                    max: 60,
                    divisions: 11,
                    value: sessionMinutes.toDouble(),
                    activeColor: AppColors.primary,
                    onChanged: (value) {
                      setState(() => sessionMinutes = value.toInt());
                    },
                    label: "$sessionMinutes min",
                  ),

                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      "$sessionMinutes min",
                      style: AppStyles.heading2,
                    ),
                  ),

                  const SizedBox(height: 12),

                  ElevatedButton(
                    onPressed: () async {
                      await settings.saveSessionDuration(sessionMinutes);

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Configuración guardada"),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("Guardar"),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),


            // Opciones de calibración

            Text("Calibración del asistente", style: AppStyles.heading1),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ],
              ),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Realiza una calibración si notas errores en la lectura de concentración.",
                    style: AppStyles.body,
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TrainingScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("Iniciar Calibración"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
