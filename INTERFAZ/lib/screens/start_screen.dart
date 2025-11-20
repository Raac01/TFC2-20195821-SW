import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../utils/colors.dart';
import '../utils/styles.dart';
import '../services/bluetooth.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  bool isScanning = false;
  String statusMessage = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        title: const Text(
          "Conectar Asistente",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        automaticallyImplyLeading: false, //PANTALLA INICIAL
      ),

      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              // TITULO PRINCIPAL GRANDE
              Text(
                statusMessage.isEmpty ? "Asistente Cognitivo" : statusMessage,
                textAlign: TextAlign.center,
                style: AppStyles.heading1.copyWith(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),

              const SizedBox(height: 40),

              // IMAGEN CENTRAL
              Image.asset(
                "assets/images/canva.png",
                height: 160,
              ),

              const SizedBox(height: 40),

              // BOTÓN PRINCIPAL
              ElevatedButton(
                onPressed: isScanning ? null : _searchAndConnect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      vertical: 18,
                      horizontal: 50
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: isScanning
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  "Conectar Asistente",
                  style: TextStyle(fontSize: 20),
                ),
              ),

              const SizedBox(height: 30),

              // BOTÓN SECUNDARIO
              TextButton(
                onPressed: () => Navigator.pushNamed(context, "/home"),
                child: const Text(
                  "Entrar al menú sin conexión",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------------------
  // BUSCAR Y CONECTAR
  // ----------------------------------------------------------------------
  Future<void> _searchAndConnect() async {
    setState(() {
      isScanning = true;
      statusMessage = "Buscando el asistente...";
    });

    BluetoothDevice? deviceFound;

    BLEService.instance.scanDevices().listen((scanResults) async {
      for (var r in scanResults) {
        if (r.device.name == BLEService.DEVICE_NAME) {
          deviceFound = r.device;
          break;
        }
      }

      if (!mounted) return;

      if (deviceFound != null) {
        setState(() => statusMessage = "Asistente encontrado. Conectando..");

        bool ok = await BLEService.instance.connect(deviceFound!);

        if (!mounted) return;

        if (ok) {
          setState(() => statusMessage = "Conectado correctamente");

          await Future.delayed(const Duration(milliseconds: 600));

          Navigator.pushNamed(context, "/home"); // YA NO replacement
        } else {
          setState(() => statusMessage = "Error al conectar");
        }

        setState(() => isScanning = false);
      } else {
        setState(() {
          isScanning = false;
          statusMessage = "No se encontró el asistente.\nAcerque el dispositivo.";
        });
      }
    });
  }
}
