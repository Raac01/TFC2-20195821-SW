import 'package:flutter/material.dart';
import '../utils/styles.dart';
import '../utils/colors.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Asistente Cognitivo',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        elevation: 2,
      ),

      body: Padding(
        padding: const EdgeInsets.all(20.0),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Menú Principal', style: AppStyles.heading1),
            const SizedBox(height: 20),

            Center(
              child: Image.asset(
                'assets/images/canva.png',
                height: 150,
              ),
            ),

            const SizedBox(height: 30),

            // BOTÓN 1: INICIAR SESIÓN
            _buildMenuCard(
              context,
              icon: Icons.play_circle_fill,
              title: 'Iniciar Sesión',
              subtitle: 'Comenzar una sesión de estudio',
              color: AppColors.primary,
              route: '/session',
            ),

            const SizedBox(height: 20),

            //  BOTÓN 2: HISTORIAL
            _buildMenuCard(
              context,
              icon: Icons.bar_chart,
              title: 'Historial',
              subtitle: 'Ver tus sesiones anteriores',
              color: AppColors.secondary,
              route: '/history',
            ),

            const SizedBox(height: 20),

            //  BOTÓN 3: CONFIGURACIÓN
            _buildMenuCard(
              context,
              icon: Icons.settings,
              title: 'Configuración',
              subtitle: 'Ajustar la duración y parámetros',
              color: AppColors.accent,
              route: '/config',
            ),

            const SizedBox(height: 20),

            // BOTÓN 4: VOLVER A CONECTAR
            _buildMenuCard(
              context,
              icon: Icons.bluetooth_searching,
              title: 'Volver a Conectar',
              subtitle: 'Retornar a la pantalla de inicio',
              color: Colors.blueGrey,
              route: '/',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String subtitle,
        required Color color,
        required String route,
      }) {
    return InkWell(
      onTap: () => Navigator.pushReplacementNamed(context, route),

      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),

        child: Padding(
          padding: const EdgeInsets.all(20),

          child: Row(
            children: [

              CircleAvatar(
                radius: 32,
                backgroundColor: color.withOpacity(0.2),
                child: Icon(
                  icon,
                  size: 32,
                  color: color,
                ),
              ),

              const SizedBox(width: 20),

              // TEXTOS
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppStyles.heading2),
                  const SizedBox(height: 5),
                  Text(subtitle, style: AppStyles.body),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
