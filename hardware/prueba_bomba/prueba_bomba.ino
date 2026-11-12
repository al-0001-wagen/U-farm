// =====================================================================
// U Farm - PRUEBA DE BOMBAS Y SENSORES (sin internet)
// Úsenlo antes que controlador_riego.ino para revisar las conexiones.
//
// Qué hace:
//   - Enciende la bomba de la zona 1 durante 5 s, espera 10 s,
//     luego la de la zona 2, y repite.
//   - Cada segundo muestra en el Monitor Serie (115200 baudios) la
//     lectura de los dos sensores de humedad.
//
// Calibrar los sensores:
//   1. Con el sensor al aire, anoten el número que aparece: es LECTURA_SECO.
//   2. Con el sensor en un vaso de agua (solo hasta la línea): LECTURA_MOJADO.
//   3. Pongan esos números en controlador_riego.ino.
//
// Medir el caudal: pongan la boquilla dentro de una taza medidora,
// dejen la bomba los 5 s y multipliquen los mililitros por 12:
// eso son mL por minuto (divídanlo entre 1000 para L/min).
//
// Si las bombas se prenden al revés (encendidas cuando deberían estar
// apagadas), cambien RELE_ACTIVO_EN_BAJO a false.
// Nunca dejen una bomba encendida fuera del agua.
// =====================================================================

const bool RELE_ACTIVO_EN_BAJO = true;
const int PIN_BOMBA[]   = {25, 26};
const int PIN_HUMEDAD[] = {34, 35};
const unsigned long ENCENDIDA_MS = 5000;
const unsigned long PAUSA_MS = 10000;

void ponerBomba(int i, bool encendida) {
  bool nivel = RELE_ACTIVO_EN_BAJO ? !encendida : encendida;
  digitalWrite(PIN_BOMBA[i], nivel ? HIGH : LOW);
}

void setup() {
  Serial.begin(115200);
  for (int i = 0; i < 2; i++) {
    pinMode(PIN_BOMBA[i], OUTPUT);
    ponerBomba(i, false);
  }
  analogReadResolution(12);
  Serial.println("Prueba de bombas y sensores");
}

void loop() {
  static int zona = 0;
  static bool encendida = false;
  static unsigned long cambio = 0, tLectura = 0;
  unsigned long ahora = millis();

  if (!encendida && ahora - cambio >= PAUSA_MS) {
    ponerBomba(zona, true);
    encendida = true;
    cambio = ahora;
    Serial.printf(">>> Bomba de la zona %d ENCENDIDA\n", zona + 1);
  } else if (encendida && ahora - cambio >= ENCENDIDA_MS) {
    ponerBomba(zona, false);
    encendida = false;
    cambio = ahora;
    Serial.printf(">>> Bomba de la zona %d apagada\n", zona + 1);
    zona = (zona + 1) % 2;
  }

  if (ahora - tLectura >= 1000) {
    tLectura = ahora;
    Serial.printf("Humedad  zona 1: %4d   zona 2: %4d\n",
                  analogRead(PIN_HUMEDAD[0]), analogRead(PIN_HUMEDAD[1]));
  }
  delay(10);
}
