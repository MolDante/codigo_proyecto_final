/**
 * Interfaz.pde - Boton y funciones auxiliares de dibujo.
 */

/** Boton rectangular con efecto al pasar el mouse. */
class BotonUI {
  float x, y, w, h;
  String texto;
  color base;
  boolean habilitado = true;

  BotonUI(float x, float y, float w, float h, String texto, color base) {
    this.x = x;
    this.y = y;
    this.w = w;
    this.h = h;
    this.texto = texto;
    this.base = base;
  }

  /** @return true si el punto (px, py) esta dentro del boton. */
  boolean contiene(float px, float py) {
    return px >= x && px <= x + w && py >= y && py <= y + h;
  }

  /** Dibuja el boton. */
  void dibujar() {
    boolean sobre = habilitado && contiene(mouseX, mouseY);
    noStroke();
    if (!habilitado) fill(70, 74, 84);
    else if (sobre) fill(red(base) + 35, green(base) + 35, blue(base) + 35);
    else fill(base);
    rect(x, y, w, h, 8);
    fill(habilitado ? 255 : 150);
    textAlign(CENTER, CENTER);
    textSize(16);
    text(texto, x + w / 2, y + h / 2);
  }
}

/** Titulo de seccion del panel izquierdo. */
void encabezado(String titulo, float y) {
  fill(0, 190, 255);
  textAlign(LEFT, TOP);
  textSize(12);
  text(titulo, 20, y);
  stroke(50, 60, 78);
  line(20, y + 15, 320, y + 15);
  noStroke();
}

/** Cuadro con cruz que muestra la posicion de un joystick (valores -100..100). */
void dibujarPalanca(float x, float y, float lado, String titulo, float vx, float vy) {
  fill(200);
  textAlign(LEFT, BOTTOM);
  textSize(13);
  text(titulo, x, y - 4);

  stroke(70);
  fill(28, 34, 46);
  rect(x, y, lado, lado, 6);
  stroke(55);
  line(x + lado / 2, y, x + lado / 2, y + lado);
  line(x, y + lado / 2, x + lado, y + lado / 2);

  float px = x + lado / 2 + constrain(vx, -100, 100) / 100.0 * lado / 2;
  float py = y + lado / 2 - constrain(vy, -100, 100) / 100.0 * lado / 2;
  noStroke();
  fill(0, 200, 255);
  ellipse(px, py, 14, 14);
}

/** Dibuja un LED virtual con su etiqueta. */
void dibujarLed(float x, float y, String etiqueta, color encendido, boolean on) {
  noStroke();
  fill(on ? encendido : color(50, 55, 65));
  ellipse(x, y, 16, 16);
  fill(190);
  textAlign(LEFT, CENTER);
  textSize(11);
  text(etiqueta, x + 12, y);
}

/** Cartel de peligro por movimientos bruscos. */
void dibujarAlertaPeligro() {
  boolean parpadeo = (millis() / 300) % 2 == 0;
  noStroke();
  fill(parpadeo ? color(220, 30, 30, 240) : color(150, 20, 20, 240));
  rect(350, 70, 620, 74, 10);

  // triangulo de advertencia
  fill(255, 215, 0);
  triangle(385, 82, 360, 128, 410, 128);
  fill(0);
  textAlign(CENTER, CENTER);
  textSize(26);
  text("!", 385, 112);

  fill(255);
  textAlign(LEFT, CENTER);
  textSize(26);
  text("PELIGRO: MOVIMIENTO BRUSCO", 430, 98);
  textSize(14);
  text("Estabiliza los joysticks. El cartel se quita solo cuando las coordenadas se estabilicen.", 430, 126);
}

/** Mensaje grande centrado sobre la escena. */
void dibujarMensajeCentral(String titulo, String detalle) {
  noStroke();
  fill(10, 14, 22, 215);
  rect(380, 270, 580, 120, 12);
  fill(255);
  textAlign(CENTER, CENTER);
  textSize(24);
  text(titulo, 670, 307);
  fill(190);
  textSize(14);
  text(detalle, 670, 352);
}
