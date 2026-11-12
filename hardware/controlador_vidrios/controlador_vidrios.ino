// =====================================================================
// U Farm - CONTROLADOR DEL VIDRIO DEL TECHO (versión maqueta, servo)
// Desliza el vidrio de acrílico con un servo MG90S, un engrane y una
// cremallera.
//
//   - Manual: la app ordena abrir, cerrar, detener o llevarlo a un %.
//   - Automático: la apertura depende de la temperatura interior.
//   - Protección: cierra solo si llueve (sensor de lluvia o pronóstico)
//     o si hay viento fuerte.
//
// LAS FUNCIONES LINEALES DEL PROYECTO
// 1) El engrane convierte el giro del servo en avance recto:
//        x = r · θ        (θ en radianes, r = radio del engrane)
// 2) El programa gira el servo a velocidad constante, así que la
//    posición del vidrio es una función lineal del tiempo:
//        x(t) = x0 ± v · t     dominio 0 ≤ t ≤ T = L / v,  rango 0 ≤ x ≤ L
// 3) En modo automático, la apertura depende linealmente de la
//    temperatura:  A(T) = 100 · (T − Tc) / (Ta − Tc), entre 0 y 100 %.
//
// Material: ESP32, servo MG90S de 180°, engrane de ~60 mm con su
// cremallera, sensor DHT22 y sensor de lluvia FC-37 / YL-83.
//
// Conexiones:
//   Servo: café -> GND del eliminador, rojo -> 5 V del eliminador,
//          naranja -> GPIO 18.  Unan el GND de la ESP32 con el del eliminador.
//          Capacitor de 470 uF entre 5 V y GND, pegado al servo.
//   DHT22: VCC -> 3V3, GND -> GND, DATA -> GPIO 4
//   Sensor de lluvia (placa comparadora): VCC -> 3V3, GND -> GND, AO -> GPIO 32
//
// Librerías: "ArduinoJson" (v7), "DHT sensor library" de Adafruit y
// "ESP32Servo" de Kevin Harrington.
//
// Antes de montar el engrane, carguen prueba_servo.ino para dejar el
// servo en 0° con el vidrio cerrado.
// Ruta en Firebase: /vidrios/techo/{config, comando, estado}
// =====================================================================

#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <DHT.h>
#include <ESP32Servo.h>
#include <Preferences.h>

// ---------- CONFIGURACIÓN ----------
const char* WIFI_NOMBRE  = "NOMBRE_DE_TU_WIFI";
const char* WIFI_CLAVE   = "CLAVE_DE_TU_WIFI";
const char* FIREBASE_URL = "https://u-farm-fbd03-default-rtdb.firebaseio.com";

const double LATITUD  = 25.6866;
const double LONGITUD = -100.3161;

// Datos de la maqueta (escala 1:50). Mídanlos en su maqueta.
const float RADIO_CM      = 3.0;   // r: radio del engrane (diámetro / 2)
const float RECORRIDO_CM  = 9.0;   // L: cuánto se desliza el vidrio
const float VELOCIDAD_CMS = 1.0;   // v: cm por segundo (tarda L / v = 9 s en abrir)

// Calibración del servo
const float ANGULO_CERRADO = 0;     // grados con el vidrio cerrado
const bool  INVERTIR_GIRO  = false; // true si al "abrir" el vidrio se cierra

// Sensor de lluvia: seco ≈ 4095, mojado baja. Con prueba_servo.ino vean
// cuánto marca con unas gotas y pongan un número entre seco y mojado.
const int UMBRAL_LLUVIA = 2500;

// Pines
const int PIN_SERVO  = 18;
const int PIN_DHT    = 4;
const int PIN_LLUVIA = 32;
// -----------------------------------

const float ANGULO_MAXIMO = ANGULO_CERRADO + (RECORRIDO_CM / RADIO_CM) * 180.0 / PI;  // θ = x / r

DHT dht(PIN_DHT, DHT22);
Servo servo;
Preferences memoria;
const char* RUTA = "/vidrios/techo/";

// Configuración (la cambia la app)
String modo = "manual";             // "manual" o "auto"
float tempCerrar = 18;              // °C: con esto o menos, cerrado
float tempAbrir = 30;               // °C: con esto o más, abierto
float vientoMax = 40;               // km/h
bool cerrarPorClima = true;

// Sensores y clima
float tempInterior = NAN;
float humedadInterior = NAN;
float viento = 0;
bool lluviaInternet = false;
bool lluviaSensor = false;

// Compartido con la tarea del servo
volatile float posicionCm = 0;      // x (0 = cerrado)
volatile int direccion = 0;         // 1 abriendo, -1 cerrando, 0 quieto
volatile float objetivoCm = 0;
volatile bool pedirMovimiento = false;
volatile bool pedirParo = false;
volatile bool guardarPosicion = false;

String motivo = "encendido";
unsigned long ultimoMovimientoAuto = 0;
bool yaMovioAuto = false;

// ---------------------------------------------------------------------
// Servo: una tarea aparte lo mueve cada 20 ms para que avance parejo
// ---------------------------------------------------------------------

float anguloDe(float xCm) {
  float theta = ANGULO_CERRADO + (xCm / RADIO_CM) * 180.0 / PI;   // θ = x / r
  return INVERTIR_GIRO ? 180.0 - theta : theta;
}

void ponerServo(float xCm) {
  // writeMicroseconds da más precisión que write(grados)
  int us = map((long)(anguloDe(xCm) * 100), 0, 18000, 500, 2400);
  servo.writeMicroseconds(us);
}

void tareaServo(void*) {
  float x0 = 0;
  unsigned long t0 = 0;
  float meta = 0;

  for (;;) {
    if (pedirParo) {
      pedirParo = false;
      direccion = 0;
      guardarPosicion = true;
    }
    if (pedirMovimiento) {
      pedirMovimiento = false;
      meta = constrain(objetivoCm, 0.0f, RECORRIDO_CM);
      x0 = posicionCm;
      t0 = millis();
      if (fabs(meta - x0) < 0.05) direccion = 0;
      else direccion = meta > x0 ? 1 : -1;
    }
    if (direccion != 0) {
      float t = (millis() - t0) / 1000.0;          // segundos
      float x = x0 + direccion * VELOCIDAD_CMS * t; // FUNCIÓN LINEAL x(t)
      bool llego = (direccion == 1 && x >= meta) || (direccion == -1 && x <= meta);
      if (llego) x = meta;
      posicionCm = x;
      ponerServo(x);
      if (llego) {
        direccion = 0;
        guardarPosicion = true;
      }
    }
    vTaskDelay(pdMS_TO_TICKS(20));
  }
}

int aperturaPct() { return round(posicionCm / RECORRIDO_CM * 100); }

void moverA(float porcentaje, const String& razon) {
  porcentaje = constrain(porcentaje, 0, 100);
  objetivoCm = porcentaje / 100.0 * RECORRIDO_CM;
  motivo = razon;
  pedirMovimiento = true;
  Serial.printf("Mover a %.0f %% (%s)\n", porcentaje, razon.c_str());
}

// ---------------------------------------------------------------------
// Internet
// ---------------------------------------------------------------------

void conectarWiFi() {
  if (WiFi.status() == WL_CONNECTED) return;
  WiFi.begin(WIFI_NOMBRE, WIFI_CLAVE);
  for (int i = 0; i < 40 && WiFi.status() != WL_CONNECTED; i++) delay(250);
}

int peticion(const char* metodo, const String& url, const String& cuerpo,
             String* respuesta = nullptr) {
  if (WiFi.status() != WL_CONNECTED) return -1;
  WiFiClientSecure cliente;
  cliente.setInsecure();   // suficiente para el prototipo escolar
  HTTPClient http;
  http.setTimeout(8000);
  if (!http.begin(cliente, url)) return -1;
  http.addHeader("Content-Type", "application/json");
  int codigo = http.sendRequest(metodo, cuerpo);
  if (respuesta != nullptr && codigo > 0) *respuesta = http.getString();
  http.end();
  return codigo;
}

String url(const char* subruta) {
  return String(FIREBASE_URL) + RUTA + subruta + ".json";
}

bool lloviendo() { return lluviaSensor || lluviaInternet; }

bool climaPeligroso() {
  return cerrarPorClima && (lloviendo() || viento >= vientoMax);
}

String razonClima() {
  if (lluviaSensor) return "cerrado: el sensor detectó lluvia";
  if (lluviaInternet) return "cerrado por lluvia";
  return "cerrado por viento fuerte";
}

void publicarEstado() {
  JsonDocument d;
  float x = posicionCm;
  int dir = direccion;
  d["apertura"] = aperturaPct();
  d["posicionCm"] = round(x * 10) / 10.0;
  d["anguloGrados"] = round(anguloDe(x));
  d["moviendo"] = dir == 1 ? "abriendo" : dir == -1 ? "cerrando" : "";
  d["motivo"] = motivo;
  if (isnan(tempInterior)) d["tempInterior"] = nullptr;
  else d["tempInterior"] = round(tempInterior * 10) / 10.0;
  if (isnan(humedadInterior)) d["humedadInterior"] = nullptr;
  else d["humedadInterior"] = round(humedadInterior);
  d["viento"] = round(viento);
  d["lloviendo"] = lloviendo();
  d["lluviaSensor"] = lluviaSensor;
  d["recorridoCm"] = RECORRIDO_CM;
  d["velocidadCmS"] = VELOCIDAD_CMS;
  d["radioCm"] = RADIO_CM;
  d["actualizado"][".sv"] = "timestamp";

  String cuerpo;
  serializeJson(d, cuerpo);
  peticion("PATCH", url("estado"), cuerpo);
}

void crearConfiguracion() {
  JsonDocument d;
  d["modo"] = "manual";
  d["tempCerrar"] = 18;
  d["tempAbrir"] = 30;
  d["vientoMax"] = 40;
  d["cerrarPorClima"] = true;
  String cuerpo;
  serializeJson(d, cuerpo);
  peticion("PUT", url("config"), cuerpo);
}

void leerFirebase() {
  String cuerpo;
  if (peticion("GET", String(FIREBASE_URL) + RUTA + ".json", "", &cuerpo) != 200) return;

  JsonDocument doc;
  if (deserializeJson(doc, cuerpo)) return;

  JsonVariant cfg = doc["config"];
  if (cfg.isNull()) {
    crearConfiguracion();
  } else {
    modo = cfg["modo"] | "manual";
    tempCerrar = cfg["tempCerrar"] | 18.0f;
    tempAbrir = cfg["tempAbrir"] | 30.0f;
    if (tempAbrir <= tempCerrar) tempAbrir = tempCerrar + 1;   // evita dividir entre 0
    vientoMax = cfg["vientoMax"] | 40.0f;
    cerrarPorClima = cfg["cerrarPorClima"] | true;
  }

  JsonVariant orden = doc["comando"];
  if (!orden.isNull()) {
    String accion = orden["accion"] | "";
    if (accion == "detener") {
      pedirParo = true;
      motivo = "detenido desde la app";
    } else if (accion == "mover") {
      float meta = orden["objetivo"] | 0.0f;
      if (meta > 0 && climaPeligroso()) {
        motivo = "no se abrió: " + String(lloviendo() ? "está lloviendo" : "hay viento fuerte");
      } else {
        moverA(meta, "desde la app");
      }
    }
    peticion("DELETE", url("comando"), "");
    publicarEstado();
  }
}

void consultarClima() {
  String u = "https://api.open-meteo.com/v1/forecast?latitude=" + String(LATITUD, 4) +
             "&longitude=" + String(LONGITUD, 4) +
             "&current=precipitation,wind_speed_10m&timezone=auto";
  String cuerpo;
  if (peticion("GET", u, "", &cuerpo) != 200) return;
  JsonDocument doc;
  if (deserializeJson(doc, cuerpo)) return;
  lluviaInternet = (doc["current"]["precipitation"] | 0.0) > 0;
  viento = doc["current"]["wind_speed_10m"] | 0.0;
}

// ---------------------------------------------------------------------
// Decisiones automáticas
// ---------------------------------------------------------------------

void decidir() {
  // 1. Protección: aplica en cualquier modo, aunque el vidrio se esté moviendo
  if (climaPeligroso()) {
    bool yaCerrando = direccion == -1 && objetivoCm == 0;
    if (aperturaPct() > 0 && !yaCerrando) moverA(0, razonClima());
    return;
  }
  if (direccion != 0) return;

  // 2. Modo automático: A(T) = 100 · (T − Tc) / (Ta − Tc), entre 0 y 100 %
  if (modo != "auto" || isnan(tempInterior)) return;

  float a = 100.0 * (tempInterior - tempCerrar) / (tempAbrir - tempCerrar);
  a = constrain(a, 0, 100);
  a = round(a / 10.0) * 10;   // en pasos de 10 % para no mover a cada rato

  bool pasoTiempo = !yaMovioAuto || millis() - ultimoMovimientoAuto > 60UL * 1000;
  if (fabs(a - aperturaPct()) >= 10 && pasoTiempo) {
    moverA(a, "automático: " + String(tempInterior, 1) + " °C adentro");
    yaMovioAuto = true;
    ultimoMovimientoAuto = millis();
  }
}

// ---------------------------------------------------------------------

void setup() {
  Serial.begin(115200);
  dht.begin();
  analogReadResolution(12);

  // Recordar dónde quedó el vidrio la última vez, para que el servo
  // no dé un brinco al encender.
  memoria.begin("vidrio", false);
  posicionCm = constrain(memoria.getFloat("x", 0), 0.0f, RECORRIDO_CM);
  objetivoCm = posicionCm;

  ESP32PWM::allocateTimer(0);
  servo.setPeriodHertz(50);
  servo.attach(PIN_SERVO, 500, 2400);
  ponerServo(posicionCm);

  xTaskCreatePinnedToCore(tareaServo, "servo", 4096, nullptr, 2, nullptr, 1);

  conectarWiFi();
  Serial.printf("Controlador de vidrio listo. Ángulo máximo: %.0f°\n", ANGULO_MAXIMO);
}

void loop() {
  static unsigned long tFirebase = 0, tSensores = 0, tClima = 0, tPublicar = 0;
  static bool primeraVez = true;
  static int direccionAnterior = 0;
  unsigned long ahora = millis();

  conectarWiFi();

  if (primeraVez || ahora - tClima >= 10UL * 60 * 1000) {   // cada 10 min
    tClima = ahora;
    consultarClima();
  }
  if (primeraVez || ahora - tSensores >= 2000) {            // cada 2 s
    tSensores = ahora;
    float t = dht.readTemperature();
    float h = dht.readHumidity();
    if (!isnan(t)) tempInterior = t;
    if (!isnan(h)) humedadInterior = h;
    bool antes = lluviaSensor;
    lluviaSensor = analogRead(PIN_LLUVIA) < UMBRAL_LLUVIA;
    decidir();
    if (lluviaSensor != antes) publicarEstado();
  }
  if (primeraVez || ahora - tFirebase >= 2000) {            // cada 2 s
    tFirebase = ahora;
    leerFirebase();
  }

  if (guardarPosicion) {
    guardarPosicion = false;
    memoria.putFloat("x", posicionCm);
  }

  // Publicar: cada segundo mientras se mueve, al detenerse y cada 30 s
  int dir = direccion;
  bool cambio = dir != direccionAnterior;
  direccionAnterior = dir;
  if (primeraVez || cambio || (dir != 0 && ahora - tPublicar >= 1000) || ahora - tPublicar >= 30000) {
    tPublicar = ahora;
    publicarEstado();
  }

  primeraVez = false;
  delay(50);
}
