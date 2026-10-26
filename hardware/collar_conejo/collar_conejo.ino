// =====================================================================
// U Farm - COLLAR DEL ANIMAL
// Mide temperatura y pulso, y los envía por radio LoRa al receptor.
//
// Material:
//   - Placa ESP32 con LoRa SX1276 a 915 MHz (TTGO LoRa32 o Heltec V2).
//     OJO: las placas con chip SX1262 (ej. Heltec V3) usan otra librería.
//   - Sensor de pulso MAX30102 (conexión I2C: SDA=21, SCL=22)
//   - Sensor de temperatura DS18B20 (pin de datos al GPIO 4,
//     con resistencia de 4.7 kΩ entre datos y 3.3 V)
//   - Batería LiPo de 3.7 V
//
// Librerías (Arduino IDE > Administrar bibliotecas):
//   - "LoRa" de Sandeep Mistry
//   - "SparkFun MAX3010x Pulse and Proximity Sensor Library"
//   - "OneWire" y "DallasTemperature"
//
// Funcionamiento: despierta, mide 15 s, envía un paquete y duerme 45 s
// para ahorrar batería. Un dato aproximadamente cada minuto.
// =====================================================================

#include <SPI.h>
#include <LoRa.h>
#include <Wire.h>
#include "MAX30105.h"   // también funciona con el MAX30102
#include "heartRate.h"
#include <OneWire.h>
#include <DallasTemperature.h>

// ---------- CONFIGURACIÓN ----------
const char* ID_ANIMAL = "conejo-01";   // un nombre distinto para cada collar

const long FRECUENCIA_LORA = 915E6;    // banda permitida en México: 902-928 MHz
const int  PALABRA_SYNC    = 0x55;     // debe ser igual en el receptor

// Pines LoRa de la TTGO LoRa32 v1.6. En Heltec V2 cambia LORA_RST a 14.
const int LORA_SCK = 5, LORA_MISO = 19, LORA_MOSI = 27;
const int LORA_SS  = 18, LORA_RST = 23, LORA_DIO0 = 26;

const int PIN_TEMPERATURA = 4;
const int PIN_BATERIA     = 35;        // a través de un divisor de voltaje 1:2

// El collar mide la temperatura de la piel, que es más baja que la
// temperatura interna. Comparen con el termómetro del veterinario y
// pongan aquí la diferencia (ej. 1.5 si el collar marca 1.5 °C menos).
const float AJUSTE_TEMPERATURA = 0.0;

const unsigned long MS_MEDICION = 15000;  // tiempo midiendo el pulso
const uint64_t SEGUNDOS_DORMIR  = 45;     // tiempo dormido entre envíos
// -----------------------------------

MAX30105 sensorPulso;
OneWire bus(PIN_TEMPERATURA);
DallasTemperature sensorTemperatura(&bus);

// Devuelve el pulso promedio en latidos por minuto, o -1 si no hubo lectura.
float medirPulso() {
  unsigned long inicio = millis();
  long ultimoLatido = 0;
  float suma = 0;
  int latidosValidos = 0;

  while (millis() - inicio < MS_MEDICION) {
    long infrarrojo = sensorPulso.getIR();
    if (infrarrojo < 50000) continue;      // el sensor no toca la piel

    if (checkForBeat(infrarrojo)) {
      long ahora = millis();
      long intervalo = ahora - ultimoLatido;
      ultimoLatido = ahora;

      float bpm = 60000.0 / intervalo;
      // Un conejo sano tiene entre 130 y 325 latidos por minuto;
      // se descartan valores imposibles causados por movimiento.
      if (bpm > 80 && bpm < 400) {
        suma += bpm;
        latidosValidos++;
      }
    }
  }
  return latidosValidos >= 5 ? suma / latidosValidos : -1;
}

// Devuelve la temperatura en °C, o -127 si el sensor no responde.
float medirTemperatura() {
  sensorTemperatura.requestTemperatures();
  float t = sensorTemperatura.getTempCByIndex(0);
  if (t == DEVICE_DISCONNECTED_C) return -127;
  return t + AJUSTE_TEMPERATURA;
}

// Porcentaje aproximado de batería (LiPo: 3.3 V vacía, 4.2 V llena).
int medirBateria() {
  float voltios = analogReadMilliVolts(PIN_BATERIA) * 2 / 1000.0;
  int porcentaje = (voltios - 3.3) / (4.2 - 3.3) * 100;
  return constrain(porcentaje, 0, 100);
}

void setup() {
  Serial.begin(115200);
  Wire.begin();
  sensorTemperatura.begin();

  // 1. Medir
  float pulso = -1;
  if (sensorPulso.begin(Wire, I2C_SPEED_FAST)) {
    sensorPulso.setup();
    sensorPulso.setPulseAmplitudeRed(0x0A);
    sensorPulso.setPulseAmplitudeGreen(0);
    pulso = medirPulso();
    sensorPulso.shutDown();               // ahorra batería
  } else {
    Serial.println("No se encontró el sensor de pulso");
  }
  float temperatura = medirTemperatura();
  int bateria = medirBateria();

  // 2. Enviar por LoRa.  Formato: id,temperatura,pulso,bateria
  String paquete = String(ID_ANIMAL) + "," + String(temperatura, 1) + "," +
                   String(pulso, 0) + "," + String(bateria);

  SPI.begin(LORA_SCK, LORA_MISO, LORA_MOSI, LORA_SS);
  LoRa.setPins(LORA_SS, LORA_RST, LORA_DIO0);
  if (LoRa.begin(FRECUENCIA_LORA)) {
    LoRa.setSpreadingFactor(10);          // más alcance (más lento)
    LoRa.setSyncWord(PALABRA_SYNC);
    LoRa.beginPacket();
    LoRa.print(paquete);
    LoRa.endPacket();
    LoRa.sleep();
    Serial.println("Enviado: " + paquete);
  } else {
    Serial.println("Error al iniciar LoRa");
  }

  // 3. Dormir. Al despertar, el programa vuelve a empezar desde setup().
  esp_sleep_enable_timer_wakeup(SEGUNDOS_DORMIR * 1000000ULL);
  esp_deep_sleep_start();
}

void loop() {
  // No se usa: el collar se reinicia después de cada siesta.
}
