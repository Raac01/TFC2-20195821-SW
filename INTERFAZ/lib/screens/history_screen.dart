import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/database.dart';
import '../models/session.dart';
import '../utils/styles.dart';
import '../utils/colors.dart';
import 'session_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<SessionModel> sessions = [];

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final data = await DatabaseService.instance.getSessions();
    setState(() => sessions = data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Historial de Sesiones',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),
        child: sessions.isEmpty
            ? const Center(
          child: Text(
            'No hay sesiones registradas.',
            style: TextStyle(fontSize: 18),
          ),
        )
            : ListView.builder(
          itemCount: sessions.length,
          itemBuilder: (context, index) {
            return _buildSessionCard(sessions[index]);
          },
        ),
      ),
    );
  }


  // LISTAR CADA SESIÓN

  Widget _buildSessionCard(SessionModel s) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SessionDetailScreen(session: s),
          ),
        );
      },
      borderRadius: BorderRadius.circular(18),

      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.black.withOpacity(0.08),
            width: 1,
          ),
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
            Text(s.date, style: AppStyles.heading2),
            const SizedBox(height: 10),

            Text("Duración: ${s.duration} min", style: AppStyles.body),
            Text("HR Promedio: ${s.avgHR} bpm", style: AppStyles.body),
            Text("Concentración Promedio: ${(s.focusLevel * 100).toInt()}%",
                style: AppStyles.body),

            const SizedBox(height: 14),

            // ⭐ TIMELINE con borde elegante ⭐
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black.withOpacity(0.1)),
              ),

              child: Row(
                children: _buildMiniFocusGraph(s),
              ),
            ),
          ],
        ),
      ),
    );
  }


  //  GRÁFICO DE ESTADOS DE CONCENTRACIÓN

  List<Widget> _buildMiniFocusGraph(SessionModel s) {
    List<dynamic> timeline = [];

    try {
      timeline = jsonDecode(s.focusTimelineJson);
    } catch (e) {
      return [const Text("Sin datos")];
    }

    if (timeline.isEmpty) {
      return [
        const Text(
          "Sin datos de concentración",
          style: TextStyle(fontSize: 12),
        )
      ];
    }

    return timeline.map((value) {
      return Expanded(
        child: Container(
          height: 12,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: value == "alta" ? Colors.green : Colors.red,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      );
    }).toList();
  }
}
