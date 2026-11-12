// =====================================================================
// U Farm - CONTROLADOR DE RIEGO (versión maqueta)
// Enciende y apaga las minibombas de agua según:
//   - órdenes de la app ("Regar ahora" / "Detener")
//   - horarios programados (ej. 06:00 y 19:00)
//   - modo automático: riega cuando el suelo está seco
// y se salta el riego si el pronóstico indica lluvia.
//
// En la maqueta los riegos duran SEGUNDOS: una minibomba de ~1.5 L/min
// llena una maceta pequeña en unos 4 segundos.
//
// Material (por zona): minibomba sumergible 3-6 V, un canal del módulo
// de relevadores y un sensor CAPACITIVO de humedad de suelo v1.2.
//
// Conexiones:
//   Eliminador 5 V (+) -> COM del relevador;  NO -> cable rojo de la bomba
//   Cable negro de la bomba -> GND del eliminador
//   Módulo de relevadores (sin el jumper JD-VCC):
//     VCC -> 3V3 de la ESP32   GND -> GND de la ESP32
//     IN1 -> GPIO 25 (zona 1)  IN2 -> GPIO 26 (zona 2)
//     JD-VCC -> 5 V del eliminador, y su GND -> GND del eliminador
//   Sensores de humedad: VCC -> 3V3, GND -> GND,
//     AOUT -> GPIO 34 (zona 1) y GPIO 35 (zona 2)
//   Capacitor de 470 uF entre 5 V y GND del eliminador.
//
// Librerías: "ArduinoJson" de Benoit Blanchon (versión 7).
// La app lee y escribe en Firebase, en la ruta /riego/zonas.
// Para probar las conexiones sin internet, usen primero prueba_bomba.ino.
// =====================================================================

#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <time.h>

// ---------- CONFIGURACIÓN ----------
const char* WIFI_NOMBRE  = "NOMBRE_DE_TU_WIFI";
const char* WIFI_CLAVE   = "CLAVE_DE_TU_WIFI";
const char* FIREBASE_URL = "https://u-farm-fbd03-default-rtdb.firebaseio.com";

// Ubicación de la granja (la misma que en clima.dart)
const double LATITUD  = 25.6866;
const double LONGITUD = -100.3161;

// Monterrey no tiene horario de verano desde 2022.
const char* ZONA_HORARIA = "CST6";

// Muchos módulos de relevadores se activan con LOW. Si al encender
// la placa se prenden las bombas, cambien esto a false.
const bool RELE_ACTIVO_EN_BAJO = true;

// Calibración del sensor de humedad (la dan los números de prueba_bomba.ino):
// lectura con el sensor al aire (seco) y dentro de un vaso de agua (mojado).
const int LECTURA_SECO   = 2800;
const int LECTURA_MOJADO = 1200;

// Seguridad
const int MAX_SEGUNDOS_RIEGO  = 60;  // ningún riego dura más que esto
const int MAX_ZONAS_A_LA_VEZ  = 1;   // una bomba a la vez, para no forzar la fuente
const int PROB_LLUVIA_SALTAR  = 60;  // % de lluvia para saltar el riego programado

// En modo automático, tiempo mínimo entre dos riegos de la misma zona.
// El agua tarda en llegar al sensor; sin esta pausa la maceta se inunda.
const unsigned long PAUSA_AUTO_MS = 2UL * 60 * 1000;  // 2 minutos

// Zonas: id en Firebase, pin del relevador, pin del sensor (-1 = sin sensor).
// Con WiFi encendido, los sensores solo funcionan en los pines 32 a 39.
struct Zona {
  const char* id;
  const char* nombreInicial;
  int pinBomba;
  int pinHumedad;

  // Configuración (la cambia la app)
  String modo = "manual";           // "manual", "horario" o "auto"
  String horarios[6];
  int numHorarios = 0;
  int duracionSeg = 5;
  int umbralHumedad = 35;           // % para el modo automático
  bool saltarSiLlueve = true;
  float caudalLpm = 1.5;            // litros por minuto de esta bomba

  // Lo que se le pide a la tarea de las bombas
  volatile int pendienteSeg = 0;    // riego en espera de turno
  volatile bool pedirParo = false;

  // Lo que maneja la tarea de las bombas
  volatile bool regando = false;
  volatile unsigned long inicioMs = 0;
  volatile unsigned long finMs = 0;
  volatile bool recienIniciado = false;
  volatile bool recienTerminado = false;
  volatile float segRegados = 0;

  // Solo para el programa principal
  String pendienteMotivo = "";
  String motivo = "";
  String motivoParo = "";
  int humedad = -1;
  bool yaRegoAuto = false;
  unsigned long ultimoAutoMs = 0;
  long ultimaClaveHorario = -1;
};

Zona zonas[] = {
  {"zona-1", "Zona 1 · aspersor", 25, 34},
  {"zona-2", "Zona 2 · gotero",   26, 35},
};
const int NUM_ZONAS = sizeof(zonas) / sizeof(zonas[0]);
// -----------------------------------

int probLluviaHoy = -1;   // -1 = todavía no se sabe
bool lloviendo = false;

// ---------------------------------------------------------------------
// Bombas: una tarea aparte las apaga a tiempo, aunque el WiFi esté lento.
// Así un riego de 5 s dura 5 s y no 7.
// ---------------------------------------------------------------------

void ponerBomba(const Zona& z, bool encendida) {
  bool nivel = RELE_ACTIVO_EN_BAJO ? !encendida : encendida;
  digitalWrite(z.pinBomba, nivel ? HIGH : LOW);
}

int zonasRegando() {
  int n = 0;
  for (int i = 0; i < NUM_ZONAS; i++) if (zonas[i].regando) n++;
  return n;
}

void apagar(Zona& z) {
  ponerBomba(z, false);
  z.segRegados = (millis() - z.inicioMs) / 1000.0;
  z.regando = false;
  z.recienTerminado = true;
}

void tareaBombas(void*) {
  for (;;) {
    unsigned long ahora = millis();
    for (int i = 0; i < NUM_ZONAS; i++) {
      Zona& z = zonas[i];
      if (z.pedirParo) {
        z.pedirParo = false;
        z.pendienteSeg = 0;
        if (z.regando) apagar(z);
      }
      if (z.regando && (long)(ahora - z.finMs) >= 0) apagar(z);
    }
    for (int i = 0; i < NUM_ZONAS; i++) {
      Zona& z = zonas[i];
      if (z.pendienteSeg > 0 && !z.regando && zonasRegando() < MAX_ZONAS_A_LA_VEZ) {
        z.inicioMs = millis();
        z.finMs = z.inicioMs + (unsigned long)z.pendienteSeg * 1000UL;
        z.pendienteSeg = 0;
        z.regando = true;
        z.recienIniciado = true;
        ponerBomba(z, true);
      }
    }
    vTaskDelay(pdMS_TO_TICKS(10));
  }
}

// ---------------------------------------------------------------------
// Internet
// ---------------------------------------------------------------------

void conectarWiFi() {
  if (WiFi.status() == WL_CONNECTED) return;
  WiFi.begin(WIFI_NOMBRE, WIFI_CLAVE);
  for (int i = 0; i < 40 && WiFi.status() != WL_CONNECTED; i++) delay(250);
}

// Hace una petición HTTP(S). Devuelve el código de respuesta.
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

String urlZona(const Zona& z, const char* subruta) {
  return String(FIREBASE_URL) + "/riego/zonas/" + z.id + "/" + subruta + ".json";
}

int leerHumedad(const Zona& z) {
  if (z.pinHumedad < 0) return -1;
  long suma = 0;
  for (int i = 0; i < 10; i++) {
    suma += analogRead(z.pinHumedad);
    delay(5);
  }
  int lectura = suma / 10;
  int porcentaje = map(lectura, LECTURA_SECO, LECTURA_MOJADO, 0, 100);
  return constrain(porcentaje, 0, 100);
}

// ---------------------------------------------------------------------
// Publicar el estado en Firebase (lo lee la app)
// ---------------------------------------------------------------------

void publicarEstado(Zona& z, bool terminoRiego = false) {
  JsonDocument d;
  d["regando"] = (bool)z.regando;
  if (z.humedad >= 0) d["humedad"] = z.humedad; else d["humedad"] = nullptr;

  long restante = 0;
  if (z.regando) {
    restante = ((long)z.finMs - (long)millis() + 999) / 1000;
    if (restante < 0) restante = 0;
  }
  d["restanteSeg"] = restante;
  d["motivo"] = z.motivo;
  d["enEspera"] = z.pendienteSeg > 0;
  if (probLluviaHoy >= 0) d["lluviaHoy"] = probLluviaHoy; else d["lluviaHoy"] = nullptr;
  d["actualizado"][".sv"] = "timestamp";

  if (terminoRiego) {
    float seg = z.segRegados;
    d["ultimoRiego"][".sv"] = "timestamp";
    d["ultimoSeg"] = round(seg * 10) / 10.0;
    d["ultimoMl"] = round(seg / 60.0 * z.caudalLpm * 1000);   // mililitros
  }

  String cuerpo;
  serializeJson(d, cuerpo);
  peticion("PATCH", urlZona(z, "estado"), cuerpo);
}

// ---------------------------------------------------------------------
// Pedir y detener riegos
// ---------------------------------------------------------------------

void pedirRiego(Zona& z, int segundos, const String& motivo) {
  if (z.regando || z.pendienteSeg > 0) return;
  z.pendienteMotivo = motivo;
  z.pendienteSeg = constrain(segundos, 1, MAX_SEGUNDOS_RIEGO);
  Serial.printf("[%s] riego en fila: %d s (%s)\n", z.id, segundos, motivo.c_str());
}

void detenerRiego(Zona& z, const String& motivo) {
  z.motivoParo = motivo;
  if (!z.regando) {
    z.pendienteSeg = 0;
    z.motivo = motivo;
    publicarEstado(z);
    return;
  }
  z.pedirParo = true;   // la tarea de las bombas la apaga
}

// Avisa a la app de lo que hizo la tarea de las bombas.
void atenderEventos() {
  for (int i = 0; i < NUM_ZONAS; i++) {
    Zona& z = zonas[i];
    if (z.recienIniciado) {
      z.recienIniciado = false;
      z.motivo = z.pendienteMotivo;
      Serial.printf("[%s] RIEGO INICIADO (%s)\n", z.id, z.motivo.c_str());
      publicarEstado(z);
    }
    if (z.recienTerminado) {
      z.recienTerminado = false;
      z.motivo = z.motivoParo.length() > 0 ? z.motivoParo : "terminado";
      z.motivoParo = "";
      Serial.printf("[%s] riego terminado: %.1f s\n", z.id, (float)z.segRegados);
      publicarEstado(z, true);
    }
  }
}

// ---------------------------------------------------------------------
// Leer configuración y órdenes desde Firebase
// ---------------------------------------------------------------------

void crearConfiguracion(Zona& z) {
  JsonDocument d;
  d["nombre"] = z.nombreInicial;
  d["modo"] = "manual";
  d["horarios"][0] = "07:00";
  d["duracionSeg"] = 5;
  d["umbralHumedad"] = 35;
  d["saltarSiLlueve"] = true;
  d["caudalLpm"] = 1.5;
  String cuerpo;
  serializeJson(d, cuerpo);
  peticion("PUT", urlZona(z, "config"), cuerpo);
}

void leerFirebase() {
  String cuerpo;
  int codigo = peticion("GET", String(FIREBASE_URL) + "/riego/zonas.json", "", &cuerpo);
  if (codigo != 200) return;

  JsonDocument doc;
  if (deserializeJson(doc, cuerpo)) return;

  for (int i = 0; i < NUM_ZONAS; i++) {
    Zona& z = zonas[i];
    JsonVariant nodo = doc[z.id];
    JsonVariant cfg = nodo["config"];

    // Primera vez (o configuración de la versión anterior): crear una nueva
    if (cfg.isNull() || cfg["duracionSeg"].isNull()) {
      crearConfiguracion(z);
      continue;
    }

    z.modo = cfg["modo"] | "manual";
    z.duracionSeg = constrain((int)(cfg["duracionSeg"] | 5), 1, MAX_SEGUNDOS_RIEGO);
    z.umbralHumedad = cfg["umbralHumedad"] | 35;
    z.saltarSiLlueve = cfg["saltarSiLlueve"] | true;
    z.caudalLpm = cfg["caudalLpm"] | 1.5f;

    z.numHorarios = 0;
    for (JsonVariant h : cfg["horarios"].as<JsonArray>()) {
      if (z.numHorarios < 6 && h.is<const char*>()) {
        z.horarios[z.numHorarios++] = h.as<String>();
      }
    }

    // Órdenes de la app
    JsonVariant orden = nodo["comando"];
    if (!orden.isNull()) {
      String accion = orden["accion"] | "";
      if (accion == "regar") {
        pedirRiego(z, orden["segundos"] | z.duracionSeg, "manual");
      } else if (accion == "detener") {
        detenerRiego(z, "detenido desde la app");
      }
      peticion("DELETE", urlZona(z, "comando"), "");   // no repetirla
    }
  }
}

// ---------------------------------------------------------------------
// Pronóstico de lluvia (Open-Meteo, gratis y sin clave)
// ---------------------------------------------------------------------

void consultarLluvia() {
  String url = "https://api.open-meteo.com/v1/forecast?latitude=" + String(LATITUD, 4) +
               "&longitude=" + String(LONGITUD, 4) +
               "&current=precipitation&daily=precipitation_probability_max" +
               "&forecast_days=1&timezone=auto";
  String cuerpo;
  if (peticion("GET", url, "", &cuerpo) != 200) return;

  JsonDocument doc;
  if (deserializeJson(doc, cuerpo)) return;
  lloviendo = (doc["current"]["precipitation"] | 0.0) > 0;
  probLluviaHoy = doc["daily"]["precipitation_probability_max"][0] | 0;
  Serial.printf("Lluvia hoy: %d %%, lloviendo ahora: %s\n", probLluviaHoy, lloviendo ? "sí" : "no");
}

bool seEsperaLluvia() {
  return lloviendo || probLluviaHoy >= PROB_LLUVIA_SALTAR;
}

// ---------------------------------------------------------------------
// Reglas de riego
// ---------------------------------------------------------------------

void revisarHorarios() {
  struct tm t;
  if (!getLocalTime(&t, 50)) return;   // todavía no hay hora de internet

  char ahora[6];
  snprintf(ahora, sizeof(ahora), "%02d:%02d", t.tm_hour, t.tm_min);
  long clave = (long)t.tm_yday * 1440 + t.tm_hour * 60 + t.tm_min;

  for (int i = 0; i < NUM_ZONAS; i++) {
    Zona& z = zonas[i];
    if (z.modo != "horario" || z.ultimaClaveHorario == clave) continue;

    for (int h = 0; h < z.numHorarios; h++) {
      if (z.horarios[h] != ahora) continue;
      z.ultimaClaveHorario = clave;   // no repetir en el mismo minuto
      if (z.saltarSiLlueve && seEsperaLluvia()) {
        z.motivo = "omitido por pronóstico de lluvia";
        publicarEstado(z);
      } else {
        pedirRiego(z, z.duracionSeg, "horario " + z.horarios[h]);
      }
    }
  }
}

void revisarModoAutomatico() {
  for (int i = 0; i < NUM_ZONAS; i++) {
    Zona& z = zonas[i];
    if (z.modo != "auto" || z.humedad < 0 || z.regando || z.pendienteSeg > 0) continue;
    if (z.humedad >= z.umbralHumedad) continue;
    if (z.yaRegoAuto && millis() - z.ultimoAutoMs < PAUSA_AUTO_MS) continue;
    if (z.saltarSiLlueve && lloviendo) continue;

    pedirRiego(z, z.duracionSeg, "suelo seco (" + String(z.humedad) + " %)");
    z.yaRegoAuto = true;
    z.ultimoAutoMs = millis();
  }
}

// ---------------------------------------------------------------------

void setup() {
  Serial.begin(115200);
  for (int i = 0; i < NUM_ZONAS; i++) {
    pinMode(zonas[i].pinBomba, OUTPUT);
    ponerBomba(zonas[i], false);   // todo apagado al arrancar
  }
  analogReadResolution(12);

  xTaskCreatePinnedToCore(tareaBombas, "bombas", 4096, nullptr, 2, nullptr, 1);

  conectarWiFi();
  configTzTime(ZONA_HORARIA, "pool.ntp.org", "time.nist.gov");
  Serial.println("Controlador de riego listo");
}

void loop() {
  static unsigned long tFirebase = 0, tClima = 0, tPublicar = 0;
  static bool primeraVez = true;
  unsigned long ahora = millis();

  conectarWiFi();

  // Cada 3 s: humedad del suelo, configuración y órdenes de la app
  if (primeraVez || ahora - tFirebase >= 3000) {
    tFirebase = ahora;
    for (int i = 0; i < NUM_ZONAS; i++) zonas[i].humedad = leerHumedad(zonas[i]);
    leerFirebase();
  }

  // Cada 30 min: pronóstico de lluvia
  if (primeraVez || ahora - tClima >= 30UL * 60 * 1000) {
    tClima = ahora;
    consultarLluvia();
  }

  revisarHorarios();
  revisarModoAutomatico();
  atenderEventos();

  // Cada 30 s: publicar el estado de todas las zonas (cada 2 s si alguna riega)
  bool alguienRiega = zonasRegando() > 0;
  if (primeraVez || ahora - tPublicar >= (alguienRiega ? 2000UL : 30000UL)) {
    tPublicar = ahora;
    for (int i = 0; i < NUM_ZONAS; i++) publicarEstado(zonas[i]);
  }

  primeraVez = false;
  delay(50);
}
