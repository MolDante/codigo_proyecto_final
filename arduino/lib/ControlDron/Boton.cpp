/**
 * @file Boton.cpp
 * @brief Implementacion de la clase Boton.
 */
#include "Boton.h"

static const unsigned long TIEMPO_REBOTE_MS = 30;

Boton::Boton(uint8_t pin) : _pin(pin) {}

void Boton::begin() {
  pinMode(_pin, INPUT_PULLUP);
}

void Boton::actualizar() {
  bool lectura = (digitalRead(_pin) == LOW);
  if (lectura != _lecturaPrevia) {
    _lecturaPrevia = lectura;
    _ultimoCambio = millis();
  }
  if ((millis() - _ultimoCambio) > TIEMPO_REBOTE_MS && lectura != _estable) {
    _estable = lectura;
    if (_estable) _flanco = true;
  }
}

bool Boton::estaPresionado() const {
  return _estable;
}

bool Boton::fuePresionado() {
  if (_flanco) {
    _flanco = false;
    return true;
  }
  return false;
}
