#include <Arduino.h>
#include <WiFi.h>
#include "esp_wifi.h"
#include <Wire.h>
#include "MAX30105.h"
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <ArduinoFFT.h>

// ==========================================================
// CONFIGURACIÓN MAX30102 — OPTIMIZADO PARA BRAZO
// ==========================================================
const int MOTOR_PIN = 2;  // D2

void setup() {
  pinMode(MOTOR_PIN, OUTPUT);
  digitalWrite(MOTOR_PIN, LOW);
  Serial.begin(115200);
}

void loop() {
  Serial.println("Motor ON");
  digitalWrite(MOTOR_PIN, HIGH);  // Enciende
  delay(2000);                    // 2 s

  Serial.println("Motor OFF");
  digitalWrite(MOTOR_PIN, LOW);   // Apaga
  delay(3000);                    // 3 s
}
