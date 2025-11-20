import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BLEService {
  static final BLEService instance = BLEService._internal();
  BLEService._internal();

  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? dataCharacteristic;

  // UUID reales del dispositivo
  static const String DEVICE_NAME = "AsistenteCognitivo";
  static const String SERVICE_UUID = "12345678-1234-5678-1234-56789abcdef0";
  static const String CHARACTERISTIC_UUID = "abcd1234-ab12-cd34-ef56-abcdef123456";


  // ESCANEAR SOLO EL DISPOSITIVO CORRECTO

  Stream<List<ScanResult>> scanDevices() {
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
    return FlutterBluePlus.scanResults;
  }

  
  // CONECTAR AL DISPOSITIVO

  Future<bool> connect(BluetoothDevice device) async {
    try {
      await device.connect(autoConnect: false);
      connectedDevice = device;

      List<BluetoothService> services = await device.discoverServices();

      for (var svc in services) {
        if (svc.uuid.toString().toLowerCase() == SERVICE_UUID.toLowerCase()) {
          for (var char in svc.characteristics) {
            if (char.uuid.toString().toLowerCase() == CHARACTERISTIC_UUID.toLowerCase()) {
              dataCharacteristic = char;

              // Activar notificaciones
              if (char.properties.notify) {
                await char.setNotifyValue(true);
              }

              return true;
            }
          }
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }


  Stream<List<int>>? listenToDevice() {
    if (dataCharacteristic == null) return null;
    return dataCharacteristic!.value;
  }


  Future<void> disconnect() async {
    await connectedDevice?.disconnect();
    connectedDevice = null;
    dataCharacteristic = null;
  }
}
