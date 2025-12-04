#include <Arduino.h>
#include <WiFi.h>
#include "esp_wifi.h"
#include <Wire.h>
#include "MAX30105.h"
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <ArduinoFFT.h>

// CONFIGURACIÓN MAX30102 
static const int PIN_SDA = 21;
static const int PIN_SCL = 22;

static const int SAMPLE_RATE_HZ = 50;
static const int PULSE_WIDTH_US = 118;
static const int ADC_RANGE_NA   = 8192;

static const float CONTACT_THR  = 40.0f;
static const float LOSE_THR     = 30.0f;

MAX30105 particleSensor;

// BLE CONFIG
static const char* BLE_NAME  = "AsistenteCognitivo";
static const char* SVC_UUID  = "12345678-1234-5678-1234-56789abcdef0";
static const char* CHAR_UUID = "abcd1234-ab12-cd34-ef56-abcdef123456";

BLECharacteristic* g_char = nullptr;
bool g_bleConnected = false;

// HRV FFT CONFIG
#define FFT_SIZE    256
#define RESAMPLE_HZ 4.0f

float vReal[FFT_SIZE];
float vImag[FFT_SIZE];
float rrInterp[FFT_SIZE];

ArduinoFFT<float> FFT(vReal, vImag, FFT_SIZE, RESAMPLE_HZ);

// AUTOCALIBRACIÓN LF/HF

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
  if (millis() - baselineStart < 60000) {
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


static const int RR_WINDOW = 100;
float rrWindow[RR_WINDOW];
int rrIndex = 0;
bool rrFull = false;

void addRR(float ms) {
  if (ms < 300 || ms > 2000) return;
  rrWindow[rrIndex] = ms / 1000.0f;  // sec
  rrIndex = (rrIndex + 1) % RR_WINDOW;
  if (rrIndex == 0) rrFull = true;
}

// INTERPOLACIÓN SOBRE VENTANA DESLIZANTE
int interpolateRR() {
  int N = rrFull ? RR_WINDOW : rrIndex;
  if (N < 8) return 0;

  float tRR[N];
  tRR[0] = 0;

  for (int i = 1; i < N; i++)
    tRR[i] = tRR[i-1] + rrWindow[(rrIndex - N + i + RR_WINDOW) % RR_WINDOW];

  float total = tRR[N - 1];
  float dt = 1.0f / RESAMPLE_HZ;

  int k = 0;
  float t = 0;

  while (t <= total && k < FFT_SIZE) {
    int j = 1;
    while (j < N && tRR[j] < t) j++;
    if (j >= N) break;

    int idx0 = (rrIndex - N + (j-1) + RR_WINDOW) % RR_WINDOW;
    int idx1 = (rrIndex - N + j + RR_WINDOW) % RR_WINDOW;

    float x0 = tRR[j-1], x1 = tRR[j];
    float y0 = rrWindow[idx0], y1 = rrWindow[idx1];
    float alpha = (t - x0) / (x1 - x0);
    rrInterp[k++] = y0 + (y1 - y0) * alpha;

    t += dt;
  }

  return k;
}

// FFT LF/HF
bool computeLFHF(float &LF, float &HF, float &ratio) {
  int N = interpolateRR();
  if (N < 32) return false;

  for (int i = 0; i < FFT_SIZE; i++) {
    vReal[i] = (i < N) ? rrInterp[i] : 0;
    vImag[i] = 0;
  }

  FFT.dcRemoval();
  FFT.windowing(FFTWindow::Hamming, FFTDirection::Forward);
  FFT.compute(FFTDirection::Forward);
  FFT.complexToMagnitude();

  float df = RESAMPLE_HZ / FFT_SIZE;

  LF = HF = 0;

  for (int i = 1; i < FFT_SIZE / 2; i++) {
    float f = i * df;
    if (f >= 0.04 && f <= 0.15) LF += vReal[i];
    else if (f >= 0.15 && f <= 0.40) HF += vReal[i];
  }

  if (HF < 1e-4) HF = 1e-4;
  ratio = LF / HF;
  return true;
}

// DETECTOR DE LATIDOS
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
    maxIR = 0;
    minIR = 1e9;
  }

  bool update(long ir) {
    buf[idx] = ir;
    idx = (idx + 1) % N;

    float smooth = 0;
    for (int i = 0; i < N; i++) smooth += buf[i];
    smooth /= N;

    if (!contact && smooth > CONTACT_THR) {
      Serial.println("Contacto en brazo detectado");
      reset();
      contact = true;
      maxIR = minIR = smooth;
      return false;
    }

    if (contact && smooth < LOSE_THR) {
      Serial.println("Contacto perdido");
      contact = false;
      reset();
      return false;
    }

    if (!contact) return false;

    maxIR = max(maxIR, smooth);
    minIR = min(minIR, smooth);
    float span = maxIR - minIR;
    if (span < 5) return false;

    float thr = minIR + span * 0.45f;

    bool beat = false;

    if (smooth > thr && smooth > last) rising = true;

    if (rising && smooth < last) {
      unsigned long now = millis();
      if (lastBeat != 0) {
        unsigned long interval = now - lastBeat;
        float bpmCalc = 60000.0f / interval;
        if (bpmCalc >= 40 && bpmCalc <= 140) {
          bpm = bpmCalc;
          addRR(interval);
          beat = true;
          Serial.printf("BPM válido: %.1f\n", bpm);
        }
      }
      lastBeat = now;
      rising = false;
    }

    last = smooth;
    return beat;
  }

} detector;


// CLASIFICACIÓN

const char* classifyState(float adj, bool ready) {

  if (!ready) return "Calibrando";

  if (adj < 0.90f) return "Alta Concentracion";
  if (adj < 1.15f) return "Moderada";
  return "Distraccion";
}



// BLE CALLBACKS

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

// PROCESAMIENTO CENTRAL: PPG + HRV + BLE
void processPPG() {

  static unsigned long lastHRV    = 0;
  static unsigned long lastNotify = 0;

  static float lastLF = 0, lastHF = 0, lastRatio = 0;
  static bool haveHRV = false;

  particleSensor.check();

  while (particleSensor.available()) {

    long ir = particleSensor.getFIFOIR();
    particleSensor.nextSample();

    if (ir == 0 || ir > 180000) continue;

    detector.update(ir);

    // HRV cada 3 s
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

// SETUP & LOOP
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
  delay(1);
}
