/**
 * @file Boton.h
 * @brief Clase para un pulsador con antirrebote (activo en LOW, con INPUT_PULLUP).
 */
#pragma once
#include <Arduino.h>

class Boton {
public:
  /** @brief Constructor. @param pin Pin digital del pulsador. */
  Boton(uint8_t pin);

  /** @brief Configura el pin como INPUT_PULLUP. */
  void begin();

  /** @brief Actualiza el estado del boton. Llamar en cada vuelta de loop(). */
  void actualizar();

  /** @brief @return true mientras el boton esta apretado. */
  bool estaPresionado() const;

  /** @brief @return true una sola vez por cada pulsacion (flanco de bajada). */
  bool fuePresionado();

private:
  uint8_t _pin;
  bool _lecturaPrevia = false;
  bool _estable = false;
  bool _flanco = false;
  unsigned long _ultimoCambio = 0;
};
