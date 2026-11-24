/**
 * Dron.pde - Modelo fisico simple y dibujo 3D del dron.
 * Usa integracion numerica (metodo de Euler) para velocidad y posicion.
 */
final float INCLINACION_MAX = 30;   // grados de inclinacion con el stick a fondo
final float GIRO_MAX = 140;         // grados/segundo de giro (yaw) con el stick a fondo
final float ALT_MAX = 220;          // altitud maxima (px)
final float LIMITE_CAMPO = 230;     // el dron se mueve en un cuadrado de +-230 px

class Dron {
  float x, z, alt;              // posicion (px). alt = altura sobre el suelo
  float vx, vz, vy;             // velocidades (px/s)
  float yaw, pitch, roll;       // orientacion (radianes)
  float potencia = 0;           // 0..1, velocidad de los rotores
  float giroRotor = 0;          // angulo de las helices
  boolean encendido = false;

  /**
   * Avanza la simulacion un paso.
   * @param dt      tiempo transcurrido (s)
   * @param activo  true si el control esta activo (si no, el dron cae al suelo)
   * @param throttle, yawIn, pitchIn, rollIn  ejes de -100 a 100
   */
  void actualizar(float dt, boolean activo, float throttle, float yawIn, float pitchIn, float rollIn) {
    encendido = activo;
    if (!activo) {
      throttle = 0;
      yawIn = 0;
      pitchIn = 0;
      rollIn = 0;
    }

    // 1) Actitud: los angulos siguen al stick con un filtro de primer orden
    float k = constrain(dt * 8, 0, 1);
    pitch += (radians(pitchIn / 100.0 * INCLINACION_MAX) - pitch) * k;
    roll += (radians(rollIn / 100.0 * INCLINACION_MAX) - roll) * k;
    yaw += radians(yawIn / 100.0 * GIRO_MAX) * dt;

    // 2) Vertical: aceleracion -> velocidad -> altura (Euler)
    float aV;
    if (activo) aV = throttle / 100.0 * 300 - 2.0 * vy;   // stick al centro = se queda en el aire
    else aV = -380 - 0.5 * vy;                            // sin control: cae
    vy += aV * dt;
    alt += vy * dt;
    if (alt < 0) { alt = 0; vy = 0; }
    if (alt > ALT_MAX) { alt = ALT_MAX; vy = 0; }

    // 3) Horizontal: la inclinacion produce aceleracion, con rozamiento
    boolean enAire = (alt > 1);
    float aF = (enAire && activo) ? sin(pitch) * 900 : 0;   // adelante
    float aD = (enAire && activo) ? sin(roll) * 900 : 0;    // derecha
    float fx = sin(yaw);
    float fz = -cos(yaw);
    float dx = cos(yaw);
    float dz = sin(yaw);
    vx += (fx * aF + dx * aD - 2.5 * vx) * dt;
    vz += (fz * aF + dz * aD - 2.5 * vz) * dt;
    if (!enAire) { vx *= 0.8; vz *= 0.8; }
    x += vx * dt;
    z += vz * dt;
    if (x > LIMITE_CAMPO) { x = LIMITE_CAMPO; vx = 0; }
    if (x < -LIMITE_CAMPO) { x = -LIMITE_CAMPO; vx = 0; }
    if (z > LIMITE_CAMPO) { z = LIMITE_CAMPO; vz = 0; }
    if (z < -LIMITE_CAMPO) { z = -LIMITE_CAMPO; vz = 0; }

    // 4) Helices
    float objetivo = activo ? 0.45 + 0.55 * max(0, throttle) / 100.0 : 0;
    potencia += (objetivo - potencia) * constrain(dt * 3, 0, 1);
    giroRotor += potencia * 45 * dt;
  }

  /** Dibuja el dron. @param peligro true para pintarlo de rojo. */
  void dibujar(boolean peligro) {
    pushMatrix();
    translate(x, SUELO_Y - 24 - alt, z);
    rotateY(-yaw);
    rotateX(pitch);
    rotateZ(roll);

    stroke(15);
    strokeWeight(1);

    // cuerpo
    fill(peligro ? color(210, 45, 45) : color(70, 130, 210));
    box(46, 14, 46);

    // brazos en X
    fill(45, 50, 60);
    pushMatrix();
    rotateY(QUARTER_PI);
    box(160, 5, 9);
    rotateY(HALF_PI);
    box(160, 5, 9);
    popMatrix();

    // nariz (indica el frente)
    pushMatrix();
    translate(0, 0, -30);
    fill(255, 150, 0);
    box(16, 8, 14);
    popMatrix();

    // rotores
    for (int sx = -1; sx <= 1; sx += 2) {
      for (int sz = -1; sz <= 1; sz += 2) {
        pushMatrix();
        translate(sx * 57, -9, sz * 57);
        rotateY(giroRotor * sx * sz);
        rotateX(HALF_PI);
        noStroke();
        fill(170, 220, 255, 55);
        ellipse(0, 0, 62, 62);
        stroke(235);
        strokeWeight(3);
        line(-30, 0, 30, 0);
        line(0, -30, 0, 30);
        strokeWeight(1);
        popMatrix();
      }
    }
    popMatrix();
  }
}
