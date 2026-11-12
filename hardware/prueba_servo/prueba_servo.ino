// =====================================================================
// U Farm - PRUEBA DEL SERVO Y DEL SENSOR DE LLUVIA (sin internet)
// Úsenlo antes que controlador_vidrios.ino.
//
// 1. MONTAJE: al encender, el servo va a 0° y se queda ahí. Con el
//    vidrio en posición CERRADA, coloquen el engrane ya engranado en la
//    cremallera y atorníllenlo al servo.
// 2. PRUEBA: abran el Monitor Serie (115200 baudios, "Nueva línea") y
//    escriban:
//       un número (0 a 180) -> el servo va a ese ángulo, despacio
//       a -> abre el vidrio a velocidad constante (x = v·t)
//       c -> lo cierra
//    Midan con una regla cuánto avanzó el vidrio en cada ángulo.
//    Debe cumplirse x = r · θ (θ en radianes).
// 3. LLUVIA: cada segundo se muestra la lectura del sensor de lluvia.
//    Anoten el número seco y con unas gotas, y pongan un valor intermedio
//    en UMBRAL_LLUVIA de controlador_vidrios.ino.
//
// Librería: "ESP32Servo" de Kevin Harrington.
// =====================================================================

#include <ESP32Servo.h>

const int PIN_SERVO  = 18;
const int PIN_LLUVIA = 32;
const float RADIO_CM      = 3.0;
const float RECORRIDO_CM  = 9.0;
const float VELOCIDAD_CMS = 1.0;
const float ANGULO_MAXIMO = (RECORRIDO_CM / RADIO_CM) * 180.0 / PI;   // ≈ 172°

Servo servo;
float angulo = 0;

void irA(float destino, float gradosPorSegundo) {
  destino = constrain(destino, 0, 180);
  float inicio = angulo;
  unsigned long t0 = millis();
  float duracion = fabs(destino - inicio) / gradosPorSegundo;
  while (true) {
    float t = (millis() - t0) / 1000.0;
    if (t >= duracion) break;
    angulo = inicio + (destino - inicio) * (t / duracion);   // lineal en t
    servo.writeMicroseconds(map((long)(angulo * 100), 0, 18000, 500, 2400));
    delay(20);
  }
  angulo = destino;
  servo.writeMicroseconds(map((long)(angulo * 100), 0, 18000, 500, 2400));
  float x = RADIO_CM * angulo * PI / 180.0;
  Serial.printf("Ángulo: %.0f°  ->  x = r·θ = %.2f cm\n", angulo, x);
}

void setup() {
  Serial.begin(115200);
  ESP32PWM::allocateTimer(0);
  servo.setPeriodHertz(50);
  servo.attach(PIN_SERVO, 500, 2400);
  servo.writeMicroseconds(500);   // 0°
  analogReadResolution(12);
  Serial.println("Servo en 0°. Escriban un ángulo, 'a' para abrir o 'c' para cerrar.");
  Serial.printf("Ángulo para abrir %.1f cm: %.0f°\n", RECORRIDO_CM, ANGULO_MAXIMO);
}

void loop() {
  // velocidad angular ω = v / r, en grados por segundo
  const float gradosPorSegundo = (VELOCIDAD_CMS / RADIO_CM) * 180.0 / PI;

  if (Serial.available()) {
    String linea = Serial.readStringUntil('\n');
    linea.trim();
    if (linea == "a") irA(ANGULO_MAXIMO, gradosPorSegundo);
    else if (linea == "c") irA(0, gradosPorSegundo);
    else if (linea.length() > 0) irA(linea.toFloat(), 60);
  }

  static unsigned long tLluvia = 0;
  if (millis() - tLluvia >= 1000) {
    tLluvia = millis();
    Serial.printf("Sensor de lluvia: %d\n", analogRead(PIN_LLUVIA));
  }
}
