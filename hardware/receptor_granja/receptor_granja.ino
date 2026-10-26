// =====================================================================
// U Farm - RECEPTOR DE LA GRANJA
// Recibe los paquetes LoRa de los collares y los sube a Firebase,
// de donde los lee la aplicación.
//
// Material:
//   - Otra placa ESP32 con LoRa SX1276 a 915 MHz (igual que el collar),
//     conectada a la corriente y al WiFi de la granja.
//
// Librerías: "LoRa" de Sandeep Mistry (las de WiFi y HTTP ya vienen
// incluidas con el ESP32).
// =====================================================================

#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <SPI.h>
#include <LoRa.h>

// ---------- CONFIGURACIÓN ----------
const char* WIFI_NOMBRE = "NOMBRE_DE_TU_WIFI";
const char* WIFI_CLAVE  = "CLAVE_DE_TU_WIFI";

// URL de su Realtime Database de Firebase (sin "/" al final)
const char* FIREBASE_URL = "https://TU-PROYECTO-default-rtdb.firebaseio.com";

const long FRECUENCIA_LORA = 915E6;   // igual que en el collar
const int  PALABRA_SYNC    = 0x55;    // igual que en el collar

const int LORA_SCK = 5, LORA_MISO = 19, LORA_MOSI = 27;
const int LORA_SS  = 18, LORA_RST = 23, LORA_DIO0 = 26;
// -----------------------------------

void conectarWiFi() {
  if (WiFi.status() == WL_CONNECTED) return;
  Serial.print("Conectando al WiFi");
  WiFi.begin(WIFI_NOMBRE, WIFI_CLAVE);
  for (int i = 0; i < 40 && WiFi.status() != WL_CONNECTED; i++) {
    delay(500);
    Serial.print(".");
  }
  Serial.println(WiFi.status() == WL_CONNECTED ? " listo" : " falló");
}

// Solo acepta letras, números y guiones en el ID (evita datos raros).
bool idValido(const String& id) {
  if (id.length() == 0 || id.length() > 30) return false;
  for (char c : id) {
    if (!isalnum(c) && c != '-') return false;
  }
  return true;
}

// Convierte el valor a JSON; los valores de "sin lectura" se guardan como null.
String valorJson(const String& texto, float minimoValido) {
  float v = texto.toFloat();
  return v < minimoValido ? "null" : texto;
}

void subirAFirebase(const String& paquete, int rssi) {
  // Formato del paquete: id,temperatura,pulso,bateria
  int c1 = paquete.indexOf(',');
  int c2 = paquete.indexOf(',', c1 + 1);
  int c3 = paquete.indexOf(',', c2 + 1);
  if (c1 < 0 || c2 < 0 || c3 < 0) {
    Serial.println("Paquete con formato incorrecto: " + paquete);
    return;
  }

  String id          = paquete.substring(0, c1);
  String temperatura = paquete.substring(c1 + 1, c2);
  String pulso       = paquete.substring(c2 + 1, c3);
  String bateria     = paquete.substring(c3 + 1);

  if (!idValido(id)) {
    Serial.println("ID no válido: " + id);
    return;
  }

  String json = "{";
  json += "\"temperatura\":" + valorJson(temperatura, -100) + ",";
  json += "\"pulso\":"       + valorJson(pulso, 0) + ",";
  json += "\"bateria\":"     + bateria + ",";
  json += "\"rssi\":"        + String(rssi) + ",";
  json += "\"actualizado\":{\".sv\":\"timestamp\"}";   // hora del servidor
  json += "}";

  conectarWiFi();
  if (WiFi.status() != WL_CONNECTED) return;

  WiFiClientSecure cliente;
  cliente.setInsecure();   // suficiente para el prototipo escolar

  HTTPClient http;
  http.begin(cliente, String(FIREBASE_URL) + "/ganado/" + id + ".json");
  http.addHeader("Content-Type", "application/json");
  int codigo = http.PUT(json);
  Serial.printf("Firebase respondió %d para %s\n", codigo, id.c_str());
  http.end();
}

void setup() {
  Serial.begin(115200);
  conectarWiFi();

  SPI.begin(LORA_SCK, LORA_MISO, LORA_MOSI, LORA_SS);
  LoRa.setPins(LORA_SS, LORA_RST, LORA_DIO0);
  while (!LoRa.begin(FRECUENCIA_LORA)) {
    Serial.println("Error al iniciar LoRa, reintentando...");
    delay(2000);
  }
  LoRa.setSpreadingFactor(10);
  LoRa.setSyncWord(PALABRA_SYNC);
  Serial.println("Receptor listo, esperando collares...");
}

void loop() {
  int tamano = LoRa.parsePacket();
  if (tamano > 0) {
    String paquete;
    while (LoRa.available()) paquete += (char)LoRa.read();
    int rssi = LoRa.packetRssi();   // intensidad de la señal
    Serial.printf("Recibido (%d dBm): %s\n", rssi, paquete.c_str());
    subirAFirebase(paquete, rssi);
  }
}
