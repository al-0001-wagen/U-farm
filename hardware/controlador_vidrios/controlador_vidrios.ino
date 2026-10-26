// =====================================================================
// U Farm - CONTROLADOR DE LOS VIDRIOS DEL TECHO
// Abre y cierra el vidrio corredizo del techo con un motor.
//
//   - Manual: la app ordena abrir, cerrar, detener o llevarlo a un %.
//   - Automático: la apertura depende de la temperatura interior.
//   - Protección: cierra solo si llueve o hay viento fuerte.
//
// LA FUNCIÓN LINEAL DEL PROYECTO
// El motor mueve el vidrio a velocidad constante v, así que su posición
// es una función lineal del tiempo:
//
//        x(t) = x0 ± v·t        dominio: 0 ≤ t ≤ T     rango: 0 ≤ x ≤ L
//
// donde L es lo que se desliza el vidrio y T = L / v el tiempo para
// abrirlo completo. El programa usa esta función para saber dónde está
// el vidrio sin necesidad de un sensor de posición.
//
// Material:
//   - ESP32
//   - Driver de motor BTS7960 (soporta motores de 12 V con bastante corriente)
//   - Motor de 12 V con reductora (en la maqueta) o motor de portón
//     corredizo (en la estructura real), con su riel y cremallera
//   - 2 finales de carrera (interruptores): uno en "abierto" y otro en
//     "cerrado". Recalibran la posición y evitan forzar el motor.
//   - Sensor DHT22 de temperatura y humedad interior
//
// Librerías: "ArduinoJson" (v7) y "DHT sensor library" de Adafruit.
// Ruta en Firebase: /vidrios/techo/{config, comando, estado}
// =====================================================================

#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <DHT.h>

// ---------- CONFIGURACIÓN ----------
const char* WIFI_NOMBRE  = "NOMBRE_DE_TU_WIFI";
const char* WIFI_CLAVE   = "CLAVE_DE_TU_WIFI";
const char* FIREBASE_URL = "https://TU-PROYECTO-default-rtdb.firebaseio.com";

const double LATITUD  = 25.6866;
const double LONGITUD = -100.3161;

// Datos de la función lineal. Mídanlos en su estructura o maqueta:
// L = cuánto se desliza el vidrio; v = cronometren cuánto avanza en 10 s.
const float RECORRIDO_M  = 4.5;    // L, en metros
const float VELOCIDAD_MS = 0.10;   // v, en metros por segundo

// Si no instalan finales de carrera, pongan false y cierren el vidrio
// a mano antes de encender la placa (el programa supondrá x = 0).
const bool TIENE_FINALES_DE_CARRERA = true;

// Pines
const int PIN_RPWM = 25;            // BTS7960: girar para abrir
const int PIN_LPWM = 26;            // BTS7960: girar para cerrar
const int PIN_EN   = 27;            // BTS7960: R_EN y L_EN unidos
const int PIN_FIN_ABIERTO = 32;     // interruptor a GND
const int PIN_FIN_CERRADO = 33;     // interruptor a GND
const int PIN_DHT = 4;
const int POTENCIA_MOTOR = 200;     // 0 a 255
// -----------------------------------

DHT dht(PIN_DHT, DHT22);
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
bool lloviendo = false;

// Compartido con la tarea del motor
volatile float posicionM = 0;       // x, en metros (0 = cerrado)
volatile int direccion = 0;         // 1 abriendo, -1 cerrando, 0 quieto
volatile bool calibrado = false;
volatile float objetivoM = 0;
volatile bool pedirMovimiento = false;
volatile bool pedirParo = false;
volatile bool paroPorTiempo = false;

String motivo = "encendido";
unsigned long ultimoMovimientoAuto = 0;
bool yaMovioAuto = false;

// ---------------------------------------------------------------------
// Motor (corre en su propia tarea para reaccionar rápido aunque el WiFi
// esté ocupado)
// ---------------------------------------------------------------------

void motor(int dir) {
  digitalWrite(PIN_EN, dir != 0 ? HIGH : LOW);
  analogWrite(PIN_RPWM, dir == 1 ? POTENCIA_MOTOR : 0);
  analogWrite(PIN_LPWM, dir == -1 ? POTENCIA_MOTOR : 0);
}

bool finAbierto() { return TIENE_FINALES_DE_CARRERA && digitalRead(PIN_FIN_ABIERTO) == LOW; }
bool finCerrado() { return TIENE_FINALES_DE_CARRERA && digitalRead(PIN_FIN_CERRADO) == LOW; }

void tareaMotor(void*) {
  float x0 = 0;               // posición al empezar el movimiento
  unsigned long t0 = 0;       // momento en que empezó
  float meta = 0;
  bool hastaElFinal = false;  // ir hasta tocar el final de carrera
  const unsigned long tiempoMaximo =
      (unsigned long)((RECORRIDO_M / VELOCIDAD_MS + 10) * 1000);

  for (;;) {
    if (pedirParo) {
      pedirParo = false;
      motor(0);
      direccion = 0;
    }

    if (pedirMovimiento) {
      pedirMovimiento = false;
      meta = objetivoM;
      hastaElFinal = TIENE_FINALES_DE_CARRERA &&
                     (meta <= 0.001 || meta >= RECORRIDO_M - 0.001);
      int dir;
      if (hastaElFinal) dir = meta > 0 ? 1 : -1;
      else if (fabs(meta - posicionM) < 0.01) dir = 0;
      else dir = meta > posicionM ? 1 : -1;

      x0 = posicionM;
      t0 = millis();
      paroPorTiempo = false;
      direccion = dir;
      motor(dir);
    }

    if (direccion != 0) {
      float t = (millis() - t0) / 1000.0;            // segundos
      float x = x0 + direccion * VELOCIDAD_MS * t;    // FUNCIÓN LINEAL
      posicionM = constrain(x, 0.0f, RECORRIDO_M);

      bool parar = false;
      if (direccion == 1 && finAbierto()) {
        posicionM = RECORRIDO_M; calibrado = true; parar = true;
      } else if (direccion == -1 && finCerrado()) {
        posicionM = 0; calibrado = true; parar = true;
      } else if (!hastaElFinal) {
        if ((direccion == 1 && posicionM >= meta) ||
            (direccion == -1 && posicionM <= meta)) parar = true;
      }
      if (millis() - t0 > tiempoMaximo) {   // algo lo está trabando
        paroPorTiempo = true;
        parar = true;
      }
      if (parar) {
        motor(0);
        direccion = 0;
      }
    }
    vTaskDelay(pdMS_TO_TICKS(20));
  }
}

int aperturaPct() { return round(posicionM / RECORRIDO_M * 100); }

void moverA(float porcentaje, const String& razon) {
  porcentaje = constrain(porcentaje, 0, 100);
  objetivoM = porcentaje / 100.0 * RECORRIDO_M;
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

bool climaPeligroso() {
  return cerrarPorClima && (lloviendo || viento >= vientoMax);
}

String razonClima() {
  return lloviendo ? "cerrado por lluvia" : "cerrado por viento fuerte";
}

void publicarEstado() {
  JsonDocument d;
  d["apertura"] = aperturaPct();
  int dir = direccion;
  d["moviendo"] = dir == 1 ? "abriendo" : dir == -1 ? "cerrando" : "";
  d["motivo"] = motivo;
  d["calibrado"] = (bool)calibrado;
  if (isnan(tempInterior)) d["tempInterior"] = nullptr;
  else d["tempInterior"] = round(tempInterior * 10) / 10.0;
  if (isnan(humedadInterior)) d["humedadInterior"] = nullptr;
  else d["humedadInterior"] = round(humedadInterior);
  d["viento"] = round(viento);
  d["lloviendo"] = lloviendo;
  d["recorridoM"] = RECORRIDO_M;
  d["velocidadMs"] = VELOCIDAD_MS;
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
        motivo = "no se abrió: " + String(lloviendo ? "está lloviendo" : "hay viento fuerte");
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
  lloviendo = (doc["current"]["precipitation"] | 0.0) > 0;
  viento = doc["current"]["wind_speed_10m"] | 0.0;
}

// ---------------------------------------------------------------------
// Decisiones automáticas
// ---------------------------------------------------------------------

void decidir() {
  if (direccion != 0) return;

  // 1. Protección: aplica en cualquier modo
  if (climaPeligroso()) {
    if (aperturaPct() > 0) moverA(0, razonClima());
    return;
  }

  // 2. Modo automático: OTRA FUNCIÓN LINEAL
  //    A(T) = 100 · (T − Tc) / (Ta − Tc), limitada entre 0 y 100 %
  if (modo != "auto" || isnan(tempInterior)) return;

  float a = 100.0 * (tempInterior - tempCerrar) / (tempAbrir - tempCerrar);
  a = constrain(a, 0, 100);
  a = round(a / 10.0) * 10;   // en pasos de 10 % para no mover a cada rato

  bool pasoTiempo = !yaMovioAuto || millis() - ultimoMovimientoAuto > 5UL * 60 * 1000;
  if (fabs(a - aperturaPct()) >= 10 && pasoTiempo) {
    moverA(a, "automático: " + String(tempInterior, 1) + " °C adentro");
    yaMovioAuto = true;
    ultimoMovimientoAuto = millis();
  }
}

// ---------------------------------------------------------------------

void setup() {
  Serial.begin(115200);
  pinMode(PIN_EN, OUTPUT);
  pinMode(PIN_RPWM, OUTPUT);
  pinMode(PIN_LPWM, OUTPUT);
  pinMode(PIN_FIN_ABIERTO, INPUT_PULLUP);
  pinMode(PIN_FIN_CERRADO, INPUT_PULLUP);
  motor(0);
  dht.begin();

  xTaskCreatePinnedToCore(tareaMotor, "motor", 4096, nullptr, 2, nullptr, 1);

  // Al encender no se sabe dónde quedó el vidrio: se cierra hasta tocar
  // el final de carrera, y así x vuelve a 0.
  if (TIENE_FINALES_DE_CARRERA) {
    posicionM = RECORRIDO_M;           // suponer lo peor para cerrar completo
    moverA(0, "calibrando al encender");
  } else {
    calibrado = true;
  }

  conectarWiFi();
  Serial.println("Controlador de vidrios listo");
}

void loop() {
  static unsigned long tFirebase = 0, tSensores = 0, tClima = 0, tPublicar = 0;
  static bool primeraVez = true;
  static int direccionAnterior = 0;
  static bool avisoTiempo = false;
  unsigned long ahora = millis();

  conectarWiFi();

  if (primeraVez || ahora - tClima >= 10UL * 60 * 1000) {   // cada 10 min
    tClima = ahora;
    consultarClima();
  }
  if (primeraVez || ahora - tSensores >= 10000) {            // cada 10 s
    tSensores = ahora;
    float t = dht.readTemperature();
    float h = dht.readHumidity();
    if (!isnan(t)) tempInterior = t;
    if (!isnan(h)) humedadInterior = h;
    decidir();
  }
  if (primeraVez || ahora - tFirebase >= 3000) {             // cada 3 s
    tFirebase = ahora;
    leerFirebase();
  }

  if (paroPorTiempo && !avisoTiempo) {
    motivo = "se detuvo por tiempo máximo: revisa el motor o si hay un obstáculo";
    avisoTiempo = true;
  }
  if (!paroPorTiempo) avisoTiempo = false;

  // Publicar: seguido mientras se mueve, al detenerse y cada 30 s
  int dir = direccion;
  bool cambio = dir != direccionAnterior;
  direccionAnterior = dir;
  if (cambio || (dir != 0 && ahora - tPublicar >= 2000) || ahora - tPublicar >= 30000) {
    tPublicar = ahora;
    publicarEstado();
  }

  primeraVez = false;
  delay(100);
}
