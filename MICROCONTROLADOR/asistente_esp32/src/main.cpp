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
static const int PIN_SDA = 21;
static const int PIN_SCL = 22;

static const int SAMPLE_RATE_HZ = 50;
static const int PULSE_WIDTH_US = 118;
static const int ADC_RANGE_NA   = 8192;

// Estos umbrales son sobre la señal suavizada (filtrada)
static const float CONTACT_THR  = 40.0f;
static const float LOSE_THR     = 30.0f;

MAX30105 particleSensor;

// ==========================================================
// BLE CONFIG
// ==========================================================
static const char* BLE_NAME  = "AsistenteCognitivo";
static const char* SVC_UUID  = "12345678-1234-5678-1234-56789abcdef0";
static const char* CHAR_UUID = "abcd1234-ab12-cd34-ef56-abcdef123456";

BLECharacteristic* g_char = nullptr;
bool g_bleConnected = false;

// ==========================================================
// FFT HRV
// ==========================================================
#define FFT_SIZE    128
#define RESAMPLE_HZ 4.0f

float vReal[FFT_SIZE];
float vImag[FFT_SIZE];
float rrInterp[FFT_SIZE];
float rrSec[200];
float tRR[200];

ArduinoFFT<float> FFT(vReal, vImag, FFT_SIZE, RESAMPLE_HZ);

// ==========================================================
// AUTOCALIBRACIÓN LF/HF
// ==========================================================
bool baselineReady = false;
float baselineLFHF = 1.8f;
float baselineAccum = 0;
int baselineSamples = 0;
unsigned long baselineStart = 0;

void startBaselineCalibration() {
  baselineReady = false;
  baselineSamples = 0;
  baselineAccum = 0;
  baselineStart = millis();
  Serial.println("Calibración LF/HF del usuario iniciada...");
}

void updateBaseline(float ratio) {
  if (baselineReady) return;

  // 60 s de ventana de calibración
  if (millis() - baselineStart < 60000) {
    // Rango razonable de LF/HF
    if (ratio > 0.1f && ratio < 8.0f) {
      baselineAccum += ratio;
      baselineSamples++;
    }
    return;
  }

  if (baselineSamples >= 5) {
    baselineLFHF = baselineAccum / baselineSamples;
    Serial.printf("Baseline LF/HF calculado = %.2f (%d muestras)\n",
                  baselineLFHF, baselineSamples);
  } else {
    Serial.println("Baseline insuficiente. Usando 1.80 por defecto.");
    baselineLFHF = 1.80f;
  }

  baselineReady = true;
}

// ==========================================================
// RR BUFFER
// ==========================================================
struct RRData {
  static const int MAX = 200;
  float rr[MAX];
  int count = 0;

  void add(float ms) {
    
    if (ms < 300.0f || ms > 2000.0f) return;
    if (count < MAX) rr[count++] = ms;
    else {
      for (int i = 1; i < MAX; i++) rr[i-1] = rr[i];
      rr[MAX-1] = ms;
    }
  }

  void clear() { count = 0; }
} rrdb;

// ==========================================================
// DETECTOR DE LATIDOS 
// ==========================================================
struct HRDetector {

  static const int N = 10;
  float buf[N] = {0};
  int idx = 0;

  float last = 0;
  bool rising = false;
  unsigned long lastBeat = 0;
  float bpm = 0;

  float maxIR = 0, minIR = 1e9;
  bool contact = false;

  void reset() {
    for (int i = 0; i < N; i++) buf[i] = 0;
    idx = 0;
    last = 0;
    rising = false;
    lastBeat = 0;
    bpm = 0;
    rrdb.clear();
    maxIR = 0;
    minIR = 1e9;
  }

  bool update(long ir) {

    // Promedio móvil simple
    buf[idx] = ir;
    idx = (idx + 1) % N;

    float smooth = 0;
    for (int i = 0; i < N; i++) smooth += buf[i];
    smooth /= N;

    // Detección de contacto brazo
    if (!contact && smooth > CONTACT_THR) {
      Serial.println("Contacto en brazo detectado");
      reset();
      contact = true;
      maxIR = smooth;
      minIR = smooth;
      return false;
    }

    // Pérdida de contacto
    if (contact && smooth < LOSE_THR) {
      Serial.println("Contacto perdido ");
      contact = false;
      reset();
      return false;
    }

    if (!contact) return false;

    // Rango dinámico mínimo
    maxIR = max(maxIR, smooth);
    minIR = min(minIR, smooth);
    float span = maxIR - minIR;
    if (span < 5.0f) return false;

    // Umbral adaptativo
    float thr = minIR + span * 0.45f;

    bool beat = false;

    // Fase ascendente
    if (smooth > thr && smooth > last)
      rising = true;

    // Pico 
    if (rising && smooth < last) {

      unsigned long now = millis();

      if (lastBeat != 0) {
        unsigned long interval = now - lastBeat;   // ms
        float bpmCalc = 60000.0f / interval;

        // Filtro adicional: solo BPM entre 40 y 140
        if (bpmCalc >= 40.0f && bpmCalc <= 140.0f) {
          bpm = bpmCalc;
          rrdb.add((float)interval);
          beat = true;
          Serial.printf("BPM válido: %.1f \n",
                        bpm, interval);
        }
      }

      lastBeat = now;
      rising = false;
    }

    last = smooth;
    return beat;
  }

} detector;

// ==========================================================
// INTERPOLACIÓN RR
// ==========================================================
int interpolateRR() {
  // Más permisivo: basta con 5 RR válidos
  if (rrdb.count < 5) return 0;

  // Pasamos a segundos
  for (int i = 0; i < rrdb.count; i++)
    rrSec[i] = rrdb.rr[i] / 1000.0f;

  tRR[0] = 0;
  for (int i = 1; i < rrdb.count; i++)
    tRR[i] = tRR[i-1] + rrSec[i];

  float total = tRR[rrdb.count - 1];
  float dt = 1.0f / RESAMPLE_HZ;

  int k = 0;
  float t = 0;

  while (t <= total && k < FFT_SIZE) {
    int j = 1;
    while (j < rrdb.count && tRR[j] < t) j++;
    if (j >= rrdb.count) break;

    float x0 = tRR[j-1], x1 = tRR[j];
    float y0 = rrSec[j-1], y1 = rrSec[j];
    float alpha = (t - x0) / (x1 - x0);
    rrInterp[k++] = y0 + (y1 - y0) * alpha;

    t += dt;
  }

  return k;
}

// ==========================================================
// FFT LF/HF
// ==========================================================
bool computeLFHF(float &LF, float &HF, float &ratio) {
  int N = interpolateRR();
  // Aceptamos FFT con mínimo 32 muestras útiles
  if (N < 32) return false;

  for (int i = 0; i < FFT_SIZE; i++) {
    vReal[i] = (i < N) ? rrInterp[i] : 0.0f;
    vImag[i] = 0.0f;
  }

  FFT.dcRemoval();
  FFT.windowing(FFTWindow::Hamming, FFTDirection::Forward);
  FFT.compute(FFTDirection::Forward);
  FFT.complexToMagnitude();

  float df = RESAMPLE_HZ / FFT_SIZE;

  LF = 0;
  HF = 0;

  for (int i = 1; i < FFT_SIZE / 2; i++) {
    float f = i * df;
    if      (f >= 0.04f && f <= 0.15f) LF += vReal[i];
    else if (f >= 0.15f && f <= 0.40f) HF += vReal[i];
  }

  if (HF < 0.0001f) HF = 0.0001f;
  ratio = LF / HF;

  return true;
}


// CLASIFICACIÓN 
// ==========================================================
const char* classifyState(float adj, bool ready) {
  if (!ready) return "Calibrando";
  if (adj < 0.80f) return "Alta Concentracion";
  if (adj < 1.40f) return "Moderada";
  return "Distraccion";
}


// BLE CALLBACKS
// ==========================================================
class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer*) override {
    g_bleConnected = true;
    Serial.println("BLE conectado");
  }
  void onDisconnect(BLEServer*) override {
    g_bleConnected = false;
    BLEDevice::startAdvertising();
  }
};


// INIT MAX30102
// ==========================================================
void disableWiFi() {
  WiFi.disconnect(true);
  WiFi.mode(WIFI_OFF);
  esp_wifi_stop();
}

bool initMAX30102() {
  Wire.begin(PIN_SDA, PIN_SCL);
  Wire.setClock(100000);

  if (!particleSensor.begin(Wire, I2C_SPEED_FAST)) {
    Serial.println("MAX30102 no detectado");
    return false;
  }

  particleSensor.setup(0x1A, 4, 2, SAMPLE_RATE_HZ, PULSE_WIDTH_US, ADC_RANGE_NA);
  particleSensor.setPulseAmplitudeRed(0x1F);
  particleSensor.setPulseAmplitudeIR(0x1A);
  particleSensor.setPulseAmplitudeGreen(0);

  particleSensor.clearFIFO();

  Serial.println("MAX30102 inicializado");
  return true;
}

BLEService* initBLE() {
  BLEDevice::init(BLE_NAME);

  BLEServer* srv = BLEDevice::createServer();
  srv->setCallbacks(new MyServerCallbacks());

  BLEService* svc = srv->createService(SVC_UUID);

  g_char = svc->createCharacteristic(
    CHAR_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
  );

  g_char->setValue("Sensor listo");
  svc->start();

  return svc;
}

void startAdvertising(BLEService* svc) {
  BLEAdvertising* adv = BLEDevice::getAdvertising();
  adv->addServiceUUID(SVC_UUID);
  adv->setScanResponse(true);
  BLEDevice::startAdvertising();
}

// ==========================================================
// PPG + HRV + BLE
// ==========================================================
void processPPG() {

  static unsigned long lastHRV    = 0;
  static unsigned long lastNotify = 0;

  static float lastLF = 0, lastHF = 0, lastRatio = 0;
  static bool  haveHRV = false;

  particleSensor.check();

  while (particleSensor.available()) {

    long ir = particleSensor.getFIFOIR();
    particleSensor.nextSample();

    if (ir == 0 || ir > 180000) continue;

    detector.update(ir);

    // HRV cada 3 s (antes 5 s)
    if (millis() - lastHRV > 3000) {
      float LF, HF, R;
      if (computeLFHF(LF, HF, R)) {
        lastLF = LF;
        lastHF = HF;
        lastRatio = R;
        haveHRV = true;
        updateBaseline(R);
      }
      lastHRV = millis();
    }

    // impresión + BLE cada 1 s
    if (millis() - lastNotify > 1000) {

      if (!haveHRV) {
        Serial.printf("BPM:%.1f LF:--- HF:--- LFHF:--- Estado:Calibrando\n",
                      detector.bpm);
      }
      else {
        float adj = baselineReady ? (lastRatio / baselineLFHF) : lastRatio;
        const char* estado = classifyState(adj, baselineReady);

        Serial.printf("BPM:%.1f LF:%.4f HF:%.4f LFHF:%.4f Adj:%.2f Estado:%s\n",
                      detector.bpm, lastLF, lastHF, lastRatio, adj, estado);
      }

      // BLE
      if (g_bleConnected) {
        char msg[128];

        if (!haveHRV) {
          snprintf(msg, sizeof(msg),
                   "BPM:%.1f LF:--- HF:--- LFHF:--- Estado:Calibrando",
                   detector.bpm);
        }
        else {
          float adj = baselineReady ? (lastRatio / baselineLFHF) : lastRatio;
          const char* estado = classifyState(adj, baselineReady);

          snprintf(msg, sizeof(msg),
                  "BPM:%.1f LF:%.3f HF:%.3f LFHF:%.3f Adj:%.2f Estado:%s",
                  detector.bpm, lastLF, lastHF, lastRatio, adj, estado);
        }

        g_char->setValue(msg);
        g_char->notify();
      }

      lastNotify = millis();
    }
  }
}

// ==========================================================
// SETUP & LOOP
// ==========================================================
void setup() {
  Serial.begin(115200);
  delay(300);

  disableWiFi();
  if (!initMAX30102()) while (1);

  BLEService* svc = initBLE();
  startAdvertising(svc);

  startBaselineCalibration();

  Serial.println("Sistema listo");
}

void loop() {
  processPPG();
  delay(100);
}
