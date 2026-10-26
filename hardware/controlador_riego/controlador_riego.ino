// =====================================================================
// U Farm - CONTROLADOR DE RIEGO
// Abre y cierra las válvulas de los aspersores según:
//   - órdenes de la app ("Regar ahora" / "Detener")
//   - horarios programados (ej. 06:00 y 19:00)
//   - modo automático: riega cuando el suelo está seco
// y se salta el riego si el pronóstico indica lluvia.
//
// Material:
//   - ESP32 (cualquier modelo con WiFi)
//   - Módulo de 4 relevadores (relés)
//   - Válvulas solenoides normalmente cerradas, una por zona.
//     Pueden ser de 12 V DC (con fuente de 12 V) o de 24 V AC, las
//     típicas de los sistemas de riego de jardín (con transformador
//     de 24 V AC). El relevador sirve para ambas.
//   - Sensores CAPACITIVOS de humedad de suelo (v1.2), uno por zona.
//     No usen los resistivos de dos patitas: se oxidan en semanas.
//   - Aspersores o goteros conectados después de cada válvula.
//
// Librerías: "ArduinoJson" de Benoit Blanchon (versión 7).
//
// La app lee y escribe en Firebase, en la ruta /riego/zonas.
// =====================================================================

#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <time.h>

// ---------- CONFIGURACIÓN ----------
const char* WIFI_NOMBRE  = "NOMBRE_DE_TU_WIFI";
const char* WIFI_CLAVE   = "CLAVE_DE_TU_WIFI";
const char* FIREBASE_URL = "https://TU-PROYECTO-default-rtdb.firebaseio.com";

// Ubicación de la granja (la misma que en clima.dart)
const double LATITUD  = 25.6866;
const double LONGITUD = -100.3161;

// Monterrey no tiene horario de verano desde 2022.
const char* ZONA_HORARIA = "CST6";

// Muchos módulos de relevadores se activan con LOW. Si al encender
// la placa se abren todas las válvulas, cambien esto a false.
const bool RELE_ACTIVO_EN_BAJO = true;

// Calibración del sensor de humedad: lectura en el aire (seco)
// y con el sensor dentro de un vaso de agua (mojado).
const int LECTURA_SECO   = 2800;
const int LECTURA_MOJADO = 1200;

// Seguridad
const int MAX_MINUTOS_RIEGO   = 60;  // ningún riego dura más que esto
const int MAX_ZONAS_A_LA_VEZ  = 1;   // con más, baja la presión del agua
const int PROB_LLUVIA_SALTAR  = 60;  // % de lluvia para saltar el riego
const unsigned long PAUSA_AUTO_MS = 60UL * 60 * 1000;  // 1 h entre riegos automáticos

// Zonas: id en Firebase, pin del relevador, pin del sensor (-1 = sin sensor).
// IMPORTANTE: con WiFi encendido, los sensores solo funcionan en los
// pines 32 a 39 (los demás pines analógicos los usa el WiFi).
struct Zona {
  const char* id;
  int pinValvula;
  int pinHumedad;

  // Configuración (la cambia la app)
  String nombre = "";
  String modo = "horario";          // "manual", "horario" o "auto"
  String horarios[6];
  int numHorarios = 0;
  int duracionMin = 10;
  int umbralHumedad = 35;           // % para el modo automático
  bool saltarSiLlueve = true;
  float caudalLpm = 8;              // litros por minuto de esta zona

  // Estado (lo calcula el controlador)
  bool regando = false;
  unsigned long inicioMs = 0;
  unsigned long duracionMs = 0;
  String motivo = "";
  int humedad = -1;
  int pendienteMin = 0;             // riego en espera de turno
  String pendienteMotivo = "";
  bool yaRegoAuto = false;
  unsigned long ultimoAutoMs = 0;
  long ultimaClaveHorario = -1;
};

Zona zonas[] = {
  {"zona-1", 25, 34},
  {"zona-2", 26, 35},
  {"zona-3", 27, 32},
  {"zona-4", 14, 33},
};
const int NUM_ZONAS = sizeof(zonas) / sizeof(zonas[0]);
// -----------------------------------

int probLluviaHoy = -1;   // -1 = todavía no se sabe
bool lloviendo = false;

unsigned long ultimaLecturaFirebase = 0;
unsigned long ultimaConsultaClima = 0;
unsigned long ultimaPublicacion = 0;
bool climaConsultado = false;

// ---------------------------------------------------------------------
// Utilidades
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

void ponerValvula(const Zona& z, bool abierta) {
  bool nivel = RELE_ACTIVO_EN_BAJO ? !abierta : abierta;
  digitalWrite(z.pinValvula, nivel ? HIGH : LOW);
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

int zonasRegando() {
  int n = 0;
  for (int i = 0; i < NUM_ZONAS; i++) if (zonas[i].regando) n++;
  return n;
}

// ---------------------------------------------------------------------
// Publicar el estado en Firebase (lo lee la app)
// ---------------------------------------------------------------------

void publicarEstado(Zona& z, bool terminoRiego = false, float minutosRegados = 0) {
  JsonDocument d;
  d["regando"] = z.regando;
  if (z.humedad >= 0) d["humedad"] = z.humedad; else d["humedad"] = nullptr;

  long restante = 0;
  if (z.regando) {
    restante = ((long)z.duracionMs - (long)(millis() - z.inicioMs)) / 1000;
    if (restante < 0) restante = 0;
  }
  d["restanteSeg"] = restante;
  d["motivo"] = z.motivo;
  d["enEspera"] = z.pendienteMin > 0;
  if (probLluviaHoy >= 0) d["lluviaHoy"] = probLluviaHoy; else d["lluviaHoy"] = nullptr;
  d["actualizado"][".sv"] = "timestamp";

  if (terminoRiego) {
    d["ultimoRiego"][".sv"] = "timestamp";
    d["ultimoMin"] = round(minutosRegados * 10) / 10.0;
    d["ultimoLitros"] = round(minutosRegados * z.caudalLpm);
  }

  String cuerpo;
  serializeJson(d, cuerpo);
  peticion("PATCH", urlZona(z, "estado"), cuerpo);
}

// ---------------------------------------------------------------------
// Encender y apagar
// ---------------------------------------------------------------------

// Pone un riego en la fila; empieza cuando haya turno.
void pedirRiego(Zona& z, int minutos, const String& motivo) {
  if (z.regando) return;
  z.pendienteMin = constrain(minutos, 1, MAX_MINUTOS_RIEGO);
  z.pendienteMotivo = motivo;
  Serial.printf("[%s] riego en fila: %d min (%s)\n", z.id, z.pendienteMin, motivo.c_str());
}

void iniciarRiego(Zona& z) {
  z.regando = true;
  z.inicioMs = millis();
  z.duracionMs = (unsigned long)z.pendienteMin * 60UL * 1000UL;
  z.motivo = z.pendienteMotivo;
  z.pendienteMin = 0;
  ponerValvula(z, true);
  Serial.printf("[%s] RIEGO INICIADO (%s)\n", z.id, z.motivo.c_str());
  publicarEstado(z);
}

void detenerRiego(Zona& z, const String& motivo) {
  z.pendienteMin = 0;
  if (!z.regando) {
    z.motivo = motivo;
    publicarEstado(z);
    return;
  }
  ponerValvula(z, false);
  float minutos = (millis() - z.inicioMs) / 60000.0;
  z.regando = false;
  z.motivo = motivo;
  Serial.printf("[%s] riego detenido (%s), %.1f min\n", z.id, motivo.c_str(), minutos);
  publicarEstado(z, true, minutos);
}

// ---------------------------------------------------------------------
// Leer configuración y órdenes desde Firebase
// ---------------------------------------------------------------------

void crearConfiguracion(Zona& z, int numero) {
  JsonDocument d;
  d["nombre"] = "Zona " + String(numero);
  d["modo"] = "horario";
  d["horarios"][0] = "06:00";
  d["duracionMin"] = 10;
  d["umbralHumedad"] = 35;
  d["saltarSiLlueve"] = true;
  d["caudalLpm"] = 8;
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

    // Primera vez: crear una configuración inicial para que la app la vea
    if (cfg.isNull()) {
      crearConfiguracion(z, i + 1);
      continue;
    }

    z.nombre = cfg["nombre"] | z.id;
    z.modo = cfg["modo"] | "horario";
    z.duracionMin = constrain((int)(cfg["duracionMin"] | 10), 1, MAX_MINUTOS_RIEGO);
    z.umbralHumedad = cfg["umbralHumedad"] | 35;
    z.saltarSiLlueve = cfg["saltarSiLlueve"] | true;
    z.caudalLpm = cfg["caudalLpm"] | 8.0f;

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
        pedirRiego(z, orden["minutos"] | z.duracionMin, "manual");
      } else if (accion == "detener") {
        detenerRiego(z, "detenido desde la app");
      }
      // Borrar la orden para no repetirla
      peticion("DELETE", urlZona(z, "comando"), "");
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
        pedirRiego(z, z.duracionMin, "horario " + z.horarios[h]);
      }
    }
  }
}

void revisarModoAutomatico() {
  for (int i = 0; i < NUM_ZONAS; i++) {
    Zona& z = zonas[i];
    if (z.modo != "auto" || z.humedad < 0 || z.regando || z.pendienteMin > 0) continue;
    if (z.humedad >= z.umbralHumedad) continue;
    if (z.yaRegoAuto && millis() - z.ultimoAutoMs < PAUSA_AUTO_MS) continue;
    if (z.saltarSiLlueve && lloviendo) continue;

    pedirRiego(z, z.duracionMin, "suelo seco (" + String(z.humedad) + " %)");
    z.yaRegoAuto = true;
    z.ultimoAutoMs = millis();
  }
}

// Termina los riegos cumplidos y da turno a los que esperan.
void atenderRiegos() {
  for (int i = 0; i < NUM_ZONAS; i++) {
    Zona& z = zonas[i];
    if (z.regando && millis() - z.inicioMs >= z.duracionMs) {
      detenerRiego(z, "terminado");
    }
  }
  for (int i = 0; i < NUM_ZONAS; i++) {
    if (zonasRegando() >= MAX_ZONAS_A_LA_VEZ) break;
    if (zonas[i].pendienteMin > 0 && !zonas[i].regando) iniciarRiego(zonas[i]);
  }
}

// ---------------------------------------------------------------------

void setup() {
  Serial.begin(115200);
  for (int i = 0; i < NUM_ZONAS; i++) {
    pinMode(zonas[i].pinValvula, OUTPUT);
    ponerValvula(zonas[i], false);   // todo cerrado al arrancar
  }
  analogReadResolution(12);

  conectarWiFi();
  configTzTime(ZONA_HORARIA, "pool.ntp.org", "time.nist.gov");
  Serial.println("Controlador de riego listo");
}

void loop() {
  unsigned long ahora = millis();
  conectarWiFi();

  // Cada 10 s: humedad del suelo, configuración y órdenes de la app
  if (ahora - ultimaLecturaFirebase >= 10000 || ultimaLecturaFirebase == 0) {
    ultimaLecturaFirebase = ahora;
    for (int i = 0; i < NUM_ZONAS; i++) zonas[i].humedad = leerHumedad(zonas[i]);
    leerFirebase();
  }

  // Cada 30 min: pronóstico de lluvia
  if (!climaConsultado || ahora - ultimaConsultaClima >= 30UL * 60 * 1000) {
    ultimaConsultaClima = ahora;
    climaConsultado = true;
    consultarLluvia();
  }

  revisarHorarios();
  revisarModoAutomatico();
  atenderRiegos();   // funciona aunque se caiga el WiFi: el riego se apaga a tiempo

  // Cada 60 s: publicar el estado de todas las zonas
  if (ahora - ultimaPublicacion >= 60000) {
    ultimaPublicacion = ahora;
    for (int i = 0; i < NUM_ZONAS; i++) publicarEstado(zonas[i]);
  }

  delay(200);
}
