import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/session.dart';
import '../utils/colors.dart';
import '../utils/styles.dart';

class SessionDetailScreen extends StatelessWidget {
  final SessionModel session;

  const SessionDetailScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    // ------------------------------------------------------------------
    // DECODIFICAR TIMELINE
    // ------------------------------------------------------------------
    List<dynamic> timeline = [];
    try {
      timeline = jsonDecode(session.focusTimelineJson);
    } catch (_) {}

    // ------------------------------------------------------------------
    // CÁLCULO DE ESTADÍSTICAS
    // ------------------------------------------------------------------
    double focusPercent = session.focusLevel * 100;

    int switches = 0;
    for (int i = 1; i < timeline.length; i++) {
      if (timeline[i] != timeline[i - 1]) switches++;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Detalle de la Sesión",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // -------------------------------------------------------------
            // INFORMACIÓN GENERAL
            // -------------------------------------------------------------
            Text("Información general", style: AppStyles.heading1),
            const SizedBox(height: 15),

            _buildInfoRow("Fecha", session.date),
            _buildInfoRow("Duración", "${session.duration} min"),
            _buildInfoRow("HR Promedio", "${session.avgHR} bpm"),
            _buildInfoRow("Concentración Media", "${focusPercent.toInt()}%"),
            _buildInfoRow("Cambios de estado", "$switches"),

            const SizedBox(height: 25),

            // -------------------------------------------------------------
            // MINI INFORME INTELIGENTE
            // -------------------------------------------------------------
            Text("Resumen inteligente", style: AppStyles.heading1),
            const SizedBox(height: 10),
            _buildSmartSummary(focusPercent, switches),

            const SizedBox(height: 25),

            // -------------------------------------------------------------
            // TIMELINE DE CONCENTRACIÓN
            // -------------------------------------------------------------
            Text("Línea de concentración", style: AppStyles.heading1),
            const SizedBox(height: 10),
            _buildTimeline(timeline),

            const SizedBox(height: 25),

            // -------------------------------------------------------------
            // GRÁFICO GRANDE HR
            // -------------------------------------------------------------
            Text("Frecuencia cardíaca", style: AppStyles.heading1),
            const SizedBox(height: 10),
            SizedBox(
              height: 250,
              child: _buildHRChart(session),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // FILA DE INFORMACIÓN
  // --------------------------------------------------------------------------
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppStyles.body),
          Text(value, style: AppStyles.heading2),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // RESUMEN INTELIGENTE
  // --------------------------------------------------------------------------
  Widget _buildSmartSummary(double focusPercent, int switches) {
    String message;

    if (focusPercent > 80 && switches < 3) {
      message = "Tu concentración fue excelente y muy estable.";
    } else if (focusPercent > 60) {
      message = "Buena concentración, con algunas caídas breves.";
    } else if (focusPercent > 40) {
      message = "Hubo periodos de concentración baja.";
    } else {
      message = "La sesión tuvo poca concentración. Intenta en un ambiente más tranquilo.";
    }

    return Container(
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
      child: Text(message, style: AppStyles.body),
    );
  }

  // --------------------------------------------------------------------------
  // TIMELINE DE CONCENTRACIÓN (ALTA / BAJA)
  // --------------------------------------------------------------------------
  Widget _buildTimeline(List<dynamic> timeline) {
    if (timeline.isEmpty) {
      return const Text("No hay datos de concentración.");
    }

    return Row(
      children: timeline.map((value) {
        return Expanded(
          child: Container(
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: value == "alta" ? Colors.green : Colors.red,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }).toList(),
    );
  }

  // --------------------------------------------------------------------------
  // GRAFICO COMPLETO DE HR
  // --------------------------------------------------------------------------
  Widget _buildHRChart(SessionModel session) {
    // Convertimos avgHR a double una sola vez
    final double avg = session.avgHR.toDouble();

    List<FlSpot> sampleData = [
      FlSpot(0, avg - 5),
      FlSpot(1, avg + 3),
      FlSpot(2, avg),
      FlSpot(3, avg + 2),
      FlSpot(4, avg - 4),
    ];

    return LineChart(
      LineChartData(
        minY: 40,
        maxY: 150,
        lineBarsData: [
          LineChartBarData(
            spots: sampleData,
            isCurved: true,
            color: AppColors.primary,
            barWidth: 3,
            dotData: const FlDotData(show: false),
          )
        ],
        titlesData: const FlTitlesData(show: false),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }

}
