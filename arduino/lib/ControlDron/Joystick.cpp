/**
 * @file Joystick.cpp
 * @brief Implementacion de la clase Joystick.
 */
#include "Joystick.h"

static const int ADC_MAX = 4095;        // ADC de 12 bits del ESP32
static const int ZONA_MUERTA = 150;     // Ignora ruido cerca del centro
static const uint8_t MUESTRAS_LECTURA = 8;
static const uint8_t MUESTRAS_CALIBRACION = 64;

Joystick::Joystick(uint8_t pinX, uint8_t pinY, bool invertirX, bool invertirY)
  : _pinX(pinX), _pinY(pinY), _invertirX(invertirX), _invertirY(invertirY) {}

void Joystick::begin() {
  analogReadResolution(12);
  analogSetPinAttenuation(_pinX, ADC_11db);  // rango completo 0 a 3.3 V
  analogSetPinAttenuation(_pinY, ADC_11db);
}

void Joystick::calibrar() {
  _centroX = leerPromedio(_pinX, MUESTRAS_CALIBRACION);
  _centroY = leerPromedio(_pinY, MUESTRAS_CALIBRACION);
}

int Joystick::leerX() {
  return normalizar(leerPromedio(_pinX, MUESTRAS_LECTURA), _centroX, _invertirX);
}

int Joystick::leerY() {
  return normalizar(leerPromedio(_pinY, MUESTRAS_LECTURA), _centroY, _invertirY);
}

/**
 * @brief Promedia varias lecturas del ADC para reducir el ruido.
 * @param pin      Pin analogico a leer.
 * @param muestras Cantidad de lecturas a promediar.
 * @return Promedio crudo (0 a 4095).
 */
int Joystick::leerPromedio(uint8_t pin, uint8_t muestras) {
  long suma = 0;
  for (uint8_t i = 0; i < muestras; i++) {
    suma += analogRead(pin);
  }
  return suma / muestras;
}

/**
 * @brief Convierte una lectura cruda en un valor de -100 a 100 con zona muerta.
 * @param valorCrudo Lectura del ADC.
 * @param centro     Valor de reposo calibrado.
 * @param invertir   true para invertir el signo.
 * @return Valor normalizado de -100 a 100.
 */
int Joystick::normalizar(int valorCrudo, int centro, bool invertir) {
  int delta = valorCrudo - centro;
  if (abs(delta) < ZONA_MUERTA) return 0;

  int valor;
  if (delta > 0) {
    valor = map(delta, ZONA_MUERTA, ADC_MAX - centro, 0, 100);
  } else {
    valor = map(delta, -ZONA_MUERTA, -centro, 0, -100);
  }
  valor = constrain(valor, -100, 100);
  return invertir ? -valor : valor;
}
