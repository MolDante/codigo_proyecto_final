/**
 * @file main.cpp
 * @brief Control de dron con 2 joysticks y ESP32 (Informatica II - Tema 9).
 *
 * El ESP32 hace dos cosas a la vez:
 *   1) Se presenta por Bluetooth (BLE) como un gamepad para el celular (FeelFPV).
 *   2) Envia por USB (serie) los datos a Processing y recibe comandos de la PC.
 *
 * Estados y LEDs:
 *   CALIBRANDO : LED rojo y verde encendidos (no tocar los sticks)
 *   BUSCANDO   : LED rojo parpadeando (buscando un telefono)
 *   CONECTADO  : LED verde fijo (conectado al telefono)
 *
 * Protocolo serie (115200 baudios, una linea por mensaje):
 *   ESP32 -> PC : J,throttle,yaw,pitch,roll,btn1,btn2,estado   (estado: 0,1,2)
 *                 EVT,<CALIBRANDO|BUSCANDO|CONECTADO|APAGADO>
 *   PC -> ESP32 : CMD,OFF  (apagar el control)
 *                 CMD,CAL  (volver a calibrar el centro de los sticks)
 */
#include <Arduino.h>
#include <BleGamepad.h>
#include "esp_sleep.h"
#include "driver/rtc_io.h"
#include "Joystick.h"
#include "Boton.h"


const uint8_t PIN_J1_X = 33;        // yaw      (horizontal del stick izquierdo)
const uint8_t PIN_J1_Y = 32;        // throttle (vertical del stick izquierdo)
const uint8_t PIN_J2_X = 35;        // roll     (horizontal del stick derecho)
const uint8_t PIN_J2_Y = 34;        // pitch    (vertical del stick derecho)
const uint8_t PIN_J1_SW = 25;       // boton del stick izquierdo (tambien enciende el control)
const uint8_t PIN_J2_SW = 26;       // boton del stick derecho
const uint8_t PIN_LED_ROJO = 16;    // buscando telefono
const uint8_t PIN_LED_VERDE = 18;   // conectado al telefono

// ---------------- Configuracion ----------------
const unsigned long TIEMPO_CALIBRACION_MS = 1500;
const unsigned long PERIODO_MS = 20;               // 50 Hz
// Copia el stick derecho tambien en los ejes RX/RY, por si la app los lee de ahi.
// Si FeelFPV se confunde con los ejes duplicados, ponerlo en false.
// En la sección Configuracion de main.cpp:
const bool DUPLICAR_STICK_DERECHO = true;

// ---------------- Maquina de estados ----------------
enum Estado { CALIBRANDO, BUSCANDO, CONECTADO };

/** Valores de los 4 ejes, normalizados de -100 a 100. */
struct Ejes {
  int throttle;
  int yaw;
  int pitch;
  int roll;
};

Estado estado = CALIBRANDO;
Ejes ejes = {0, 0, 0, 0};
unsigned long tCambioEstado = 0;
unsigned long tUltimoCiclo = 0;
String bufferSerie = "";

// ---------------- Objetos ----------------
// Si al empujar un stick hacia arriba el valor baja, cambiar el 4to parametro.
Joystick joyIzq(PIN_J1_X, PIN_J1_Y, false, true);  // X = yaw,  Y = throttle
Joystick joyDer(PIN_J2_X, PIN_J2_Y, true, true);   // X = roll (invertido), Y = pitch
Boton btnIzq(PIN_J1_SW);
Boton btnDer(PIN_J2_SW);
BleGamepad bleGamepad("Dron Control UTN", "UTN FRM", 100);

/** @brief Devuelve el nombre de un estado como texto. */
const char* nombreEstado(Estado e) {
  switch (e) {
    case CALIBRANDO: return "CALIBRANDO";
    case BUSCANDO:   return "BUSCANDO";
    case CONECTADO:  return "CONECTADO";
  }
  return "?";
}

/** @brief Cambia de estado y avisa a la PC. @param nuevo Estado al que se pasa. */
void cambiarEstado(Estado nuevo) {
  estado = nuevo;
  tCambioEstado = millis();
  Serial.printf("EVT,%s\n", nombreEstado(estado));
}

/** @brief Lee los 4 ejes y los guarda en la estructura global `ejes`. */
void leerEjes() {
  ejes.yaw      = joyIzq.leerX();
  ejes.throttle = joyIzq.leerY();
  ejes.roll     = joyDer.leerX();
  ejes.pitch    = joyDer.leerY();
}

/**
 * @brief Convierte un eje de -100..100 al rango del gamepad BLE (-32767..32767).
 *        Con rango simetrico, el centro del stick es exactamente 0.
 * @param valor Eje normalizado.
 * @return Valor de -32767 a 32767.
 */
int ejeAGamepad(int valor) {
  return map(valor, -100, 100, -32767, 32767);
}

/** @brief Envia a Processing los ejes, botones y estado por el puerto serie. */
void enviarTelemetria() {
  Serial.printf("J,%d,%d,%d,%d,%d,%d,%d\n",
                ejes.throttle, ejes.yaw, ejes.pitch, ejes.roll,
                btnIzq.estaPresionado(), btnDer.estaPresionado(), (int)estado);
}

/**
 * @brief Envia al celular el estado de los sticks y botones como gamepad BLE.
 *        El eje Y se invierte porque en un gamepad "arriba" es el valor minimo.
 */
void enviarGamepadBle() {
  if (!bleGamepad.isConnected()) return;

  bleGamepad.setLeftThumb(ejeAGamepad(ejes.yaw), ejeAGamepad(-ejes.throttle));
  bleGamepad.setRightThumb(ejeAGamepad(ejes.roll), ejeAGamepad(-ejes.pitch));
  if (DUPLICAR_STICK_DERECHO) {
    bleGamepad.setRX(ejeAGamepad(ejes.roll));
    bleGamepad.setRY(ejeAGamepad(-ejes.pitch));
  }

  if (btnDer.estaPresionado()) bleGamepad.press(BUTTON_1); else bleGamepad.release(BUTTON_1);
  if (btnIzq.estaPresionado()) bleGamepad.press(BUTTON_2); else bleGamepad.release(BUTTON_2);

  bleGamepad.sendReport();
}

/**
 * @brief Apaga el control (sueno profundo). Se vuelve a encender apretando el
 *        boton del stick izquierdo o el boton EN de la placa.
 */
void apagar() {
  Serial.println("EVT,APAGADO");
  Serial.flush();
  digitalWrite(PIN_LED_ROJO, LOW);
  digitalWrite(PIN_LED_VERDE, LOW);

  // El pulsador conecta a GND: despertar cuando el pin pase a LOW
  esp_sleep_pd_config(ESP_PD_DOMAIN_RTC_PERIPH, ESP_PD_OPTION_ON);
  rtc_gpio_pullup_en((gpio_num_t)PIN_J1_SW);
  rtc_gpio_pulldown_dis((gpio_num_t)PIN_J1_SW);
  esp_sleep_enable_ext0_wakeup((gpio_num_t)PIN_J1_SW, 0);
  esp_deep_sleep_start();
}

/** @brief Interpreta una linea recibida desde la PC. @param linea Texto sin salto de linea. */
void procesarLinea(const String& linea) {
  if (linea == "CMD,OFF") {
    apagar();
  } else if (linea == "CMD,CAL") {
    cambiarEstado(CALIBRANDO);
  }
}

/** @brief Lee el puerto serie sin bloquear y procesa cada linea completa. */
void leerSerie() {
  while (Serial.available()) {
    char c = Serial.read();
    if (c == '\n') {
      procesarLinea(bufferSerie);
      bufferSerie = "";
    } else if (c != '\r') {
      bufferSerie += c;
    }
  }
}

/** @brief Actualiza la maquina de estados segun el tiempo y la conexion Bluetooth. */
void actualizarEstado() {
  switch (estado) {
    case CALIBRANDO:
      // Con los sticks quietos, mide el centro al terminar la espera.
      if (millis() - tCambioEstado >= TIEMPO_CALIBRACION_MS) {
        joyIzq.calibrar();
        joyDer.calibrar();
        cambiarEstado(BUSCANDO);
      }
      break;

    case BUSCANDO:
      if (bleGamepad.isConnected()) cambiarEstado(CONECTADO);
      break;

    case CONECTADO:
      if (!bleGamepad.isConnected()) cambiarEstado(BUSCANDO);
      break;
  }
}

/** @brief Enciende los LEDs segun el estado actual. */
void actualizarLeds() {
  bool rojo = false;
  bool verde = false;
  switch (estado) {
    case CALIBRANDO: rojo = true; verde = true; break;
    case BUSCANDO:   rojo = (millis() / 400) % 2; break;   // parpadea
    case CONECTADO:  verde = true; break;
  }
  digitalWrite(PIN_LED_ROJO, rojo);
  digitalWrite(PIN_LED_VERDE, verde);
}

void setup() {
  Serial.begin(115200);
  pinMode(PIN_LED_ROJO, OUTPUT);
  pinMode(PIN_LED_VERDE, OUTPUT);
  joyIzq.begin();
  joyDer.begin();
  btnIzq.begin();
  btnDer.begin();

  BleGamepadConfiguration configBle;
  configBle.setAutoReport(false);    // enviamos el reporte a mano
  configBle.setAxesMin(-32767);      // rango simetrico: centro = 0
  configBle.setAxesMax(32767);
  bleGamepad.begin(&configBle);

  cambiarEstado(CALIBRANDO);
}

void loop() {
  btnIzq.actualizar();
  btnDer.actualizar();
  leerSerie();
  actualizarEstado();

  if (millis() - tUltimoCiclo >= PERIODO_MS) {
    tUltimoCiclo = millis();
    if (estado != CALIBRANDO) {
      leerEjes();
      enviarTelemetria();
      enviarGamepadBle();
    }
  }

  actualizarLeds();
}
