import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import '../utils/colors.dart';
import '../utils/styles.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/session.dart';
import '../services/database.dart';
import '../services/prefs.dart';

class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  // Datos reales o simulados
  int heartRate = 0;
  String focusLevel = "–";

  // Configuración del usuario
  final SettingsService settings = SettingsService();

  // Timer
  int secondsRemaining = 0;
  int initialSeconds = 0;
  Timer? timer;

  // Simulación
  final Random rand = Random();

  // Gráfico HR
  List<FlSpot> hrData = [];
  double elapsed = 0;

  // Timeline de concentración
  List<String> focusTimeline = [];

  @override
  void initState() {
    super.initState();
    _loadSessionDuration();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }


  // CARGAR TIEMPO CONFIGURADO DESDE AJUSTES

  Future<void> _loadSessionDuration() async {
    int minutes = await settings.getSessionDuration();
    setState(() {
      secondsRemaining = minutes * 60;
      initialSeconds = minutes * 60;
    });

    _startTimer();
  }



  // SIMULACIÓN
  void _startTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (secondsRemaining > 0) {

        // SIMULACIÓN DE HR

        heartRate = 70 + rand.nextInt(50);


        // SIMULACIÓN DE CONCENTRACIÓN

        focusLevel = rand.nextBool() ? "alta" : "baja";
        focusTimeline.add(focusLevel);


        // ACTUALIZAR GRÁFICA

        elapsed += 1;

        if (hrData.isEmpty) {
          // Punto inicial para evitar gráfica vacía
          hrData.add(const FlSpot(0, 80));
        }

        if (elapsed <= 60) {
          hrData.add(FlSpot(elapsed, heartRate.toDouble()));
        } else {
          // Ventana deslizante de 60s
          hrData.removeAt(0);
          hrData.add(FlSpot(60, heartRate.toDouble()));

          // Normalizar X
          for (int i = 0; i < hrData.length; i++) {
            hrData[i] = FlSpot(i.toDouble(), hrData[i].y);
          }
        }


        // DISMINUIR TIEMPO RESTANTE

        setState(() => secondsRemaining--);
      } else {
        t.cancel();
        _saveSession();
      }
    });
  }


  // GUARDAR SESIÓN AL FINALIZAR

  Future<void> _saveSession() async {
    final timelineJson = jsonEncode(focusTimeline);

    int durationMinutes = (initialSeconds / 60).round();

    await DatabaseService.instance.insertSession(
      SessionModel(
        date: DateTime.now().toString().substring(0, 16),
        duration: durationMinutes,
        avgHR: _calculateAvgHR(),
        focusLevel: _calculateFocusLevel(),
        focusTimelineJson: timelineJson,
      ),
    );

    if (!mounted) return;
    Navigator.pop(context);
  }

  int _calculateAvgHR() {
    if (hrData.isEmpty) return 0;
    double sum = hrData.map((p) => p.y).reduce((a, b) => a + b);
    return (sum / hrData.length).round();
  }

  double _calculateFocusLevel() {
    if (focusTimeline.isEmpty) return 0;
    int high = focusTimeline.where((e) => e == "alta").length;
    return high / focusTimeline.length;
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Sesión en Tiempo Real',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
      ),

      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildInfoCard(),
              const SizedBox(height: 30),

              _buildChart(),

              const SizedBox(height: 40),

              // Timer fijo abajo
              _buildTimer(),
            ],
          ),
        ),
      ),


    );
  }

  // HR Y CONCENTRACIÓN

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Text("HR", style: AppStyles.heading2),
              const SizedBox(height: 8),
              Text(
                "$heartRate bpm",
                style: AppStyles.heading1.copyWith(color: AppColors.primary),
              ),
            ],
          ),
          Column(
            children: [
              Text("Concentración", style: AppStyles.heading2),
              const SizedBox(height: 8),
              Text(
                focusLevel,
                style: AppStyles.heading1.copyWith(color: AppColors.secondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------------
  // GRÁFICO HR
  // ----------------------------------------------------------------------
  Widget _buildChart() {
    if (hrData.isEmpty) {
      return const Center(
        child: Text(
          "Cargando datos...",
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    return Column(
      children: [
        const Text(
          "Frecuencia cardíaca (bpm)",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),

        SizedBox(
          height: 250,
          child: LineChart(
            LineChartData(
              minY: 40,
              maxY: 150,
              minX: 0,
              maxX: 60,
              lineBarsData: [
                LineChartBarData(
                  spots: hrData,
                  isCurved: true,
                  color: AppColors.primary,
                  barWidth: 4,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppColors.primary.withOpacity(0.15),
                  ),
                )
              ],
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    interval: 10,
                    getTitlesWidget: (value, meta) {
                      if (value % 10 == 0) {
                        return Text("${value.toInt()}s",
                            style: const TextStyle(fontSize: 10));
                      }
                      return const SizedBox();
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 20,
                    reservedSize: 35,
                    getTitlesWidget: (value, meta) {
                      return Text("${value.toInt()}",
                          style: const TextStyle(fontSize: 10));
                    },
                  ),
                ),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: true),
              borderData: FlBorderData(show: true),
            ),
          ),
        ),

        const SizedBox(height: 10),
        const Text(
          "Tiempo (s)",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }



  Widget _buildTimer() {
    int minutes = secondsRemaining ~/ 60;
    int seconds = secondsRemaining % 60;

    return Column(
      children: [
        const Text(
          "Tiempo restante",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}",
          style: AppStyles.heading1.copyWith(
            fontSize: 42,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }


}
