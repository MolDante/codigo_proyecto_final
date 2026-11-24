/**
 * @file Joystick.h
 * @brief Clase para leer un joystick analogico de 2 ejes en un ESP32.
 */
#pragma once
#include <Arduino.h>

class Joystick {
public:
  /**
   * @brief Constructor.
   * @param pinX      Pin analogico (ADC1) del eje X.
   * @param pinY      Pin analogico (ADC1) del eje Y.
   * @param invertirX true para invertir el sentido del eje X.
   * @param invertirY true para invertir el sentido del eje Y.
   */
  Joystick(uint8_t pinX, uint8_t pinY, bool invertirX = false, bool invertirY = false);

  /** @brief Configura la resolucion y el rango del ADC para los pines del joystick. */
  void begin();

  /** @brief Mide la posicion de reposo (centro) de ambos ejes. No tocar el joystick. */
  void calibrar();

  /** @brief Lee el eje X. @return Valor de -100 a 100 (0 dentro de la zona muerta). */
  int leerX();

  /** @brief Lee el eje Y. @return Valor de -100 a 100 (0 dentro de la zona muerta). */
  int leerY();

private:
  uint8_t _pinX, _pinY;
  bool _invertirX, _invertirY;
  int _centroX = 2048;
  int _centroY = 2048;

  int leerPromedio(uint8_t pin, uint8_t muestras);
  int normalizar(int valorCrudo, int centro, bool invertir);
};
