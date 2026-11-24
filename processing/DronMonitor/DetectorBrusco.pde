/** Muestra de los 4 ejes (-100 a 100) con su marca de tiempo en ms. */
class Muestra {
  int t;
  float throttle, yaw, pitch, roll;

  Muestra(int t, float throttle, float yaw, float pitch, float roll) {
    this.t = t;
    this.throttle = throttle;
    this.yaw = yaw;
    this.pitch = pitch;
    this.roll = roll;
  }

  /** Distancia euclidea entre dos muestras (en el espacio de los 4 ejes). */
  float distancia(Muestra o) {
    return sqrt(sq(throttle - o.throttle) + sq(yaw - o.yaw) + sq(pitch - o.pitch) + sq(roll - o.roll));
  }
}

class DetectorBrusco {
  ArrayList<Muestra> ventana = new ArrayList<Muestra>();   // ultimas muestras (1 s)
  float velocidad = 0;
  float dispersion = 0;
  float velocidadPico = 0;
  boolean peligro = false;
  int tEstableDesde = -1;
  int muestrasBruscasSeguidas = 0;

  /** Borra todo el historial. */
  void reiniciar() {
    ventana.clear();
    velocidad = 0;
    dispersion = 0;
    velocidadPico = 0;
    peligro = false;
    tEstableDesde = -1;
    muestrasBruscasSeguidas = 0;
  }

  /** Agrega una muestra nueva y recalcula velocidad, dispersion y estado de peligro. */
  void agregar(Muestra m) {
    ventana.add(m);
    while (ventana.size() > 1 && m.t - ventana.get(0).t > VENTANA_MS) ventana.remove(0);
    velocidad = calcularVelocidad(m);
    dispersion = calcularDispersion();
    evaluar(m.t);
  }

  /** Velocidad de cambio (unidades/s) respecto de una muestra de hace ~100 ms. */
  float calcularVelocidad(Muestra m) {
    for (int i = ventana.size() - 2; i >= 0; i--) {
      Muestra r = ventana.get(i);
      if (m.t - r.t >= BASE_DERIVADA_MS) {
        return m.distancia(r) / ((m.t - r.t) / 1000.0);
      }
    }
    return 0;
  }

  /** Mayor desvio estandar entre los 4 ejes dentro de la ventana. */
  float calcularDispersion() {
    int n = ventana.size();
    if (n < 5) return 0;
    float[] suma = new float[4];
    float[] sumaCuad = new float[4];
    for (Muestra s : ventana) {
      float[] v = { s.throttle, s.yaw, s.pitch, s.roll };
      for (int i = 0; i < 4; i++) {
        suma[i] += v[i];
        sumaCuad[i] += v[i] * v[i];
      }
    }
    float mayor = 0;
    for (int i = 0; i < 4; i++) {
      float media = suma[i] / n;
      float varianza = sumaCuad[i] / n - media * media;
      if (varianza < 0) varianza = 0;
      mayor = max(mayor, sqrt(varianza));
    }
    return mayor;
  }

  /** Maquina de dos estados con histeresis: tranquilo <-> peligro. */
  void evaluar(int ahora) {
    if (!peligro) {
      if (velocidad > UMBRAL_VELOCIDAD) {
        muestrasBruscasSeguidas++;
        if (muestrasBruscasSeguidas >= 3) {
          peligro = true;
          velocidadPico = velocidad;
          tEstableDesde = -1;
          muestrasBruscasSeguidas = 0;
        }
      } else {
        muestrasBruscasSeguidas = 0;
      }
    } else {
      velocidadPico = max(velocidadPico, velocidad);
      boolean estable = (dispersion < UMBRAL_DISPERSION) && (velocidad < UMBRAL_VELOCIDAD_BAJA);
      if (estable) {
        if (tEstableDesde < 0) tEstableDesde = ahora;
        else if (ahora - tEstableDesde >= TIEMPO_ESTABLE_MS) {
          peligro = false;
          tEstableDesde = -1;
        }
      } else {
        tEstableDesde = -1;
      }
    }
  }
}
