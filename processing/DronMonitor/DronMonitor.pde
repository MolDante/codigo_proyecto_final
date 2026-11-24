/**
 * DronMonitor - Interfaz en Processing para el control de dron (ESP32).
 *
 * - Recibe por USB (serie) los ejes de los dos joysticks: "J,throttle,yaw,pitch,roll,b1,b2,estado"
 * - Muestra los datos de vuelo y un dron 3D simulado que se mueve segun los joysticks.
 * - Detecta movimientos bruscos (derivada y desvio estandar de los ejes) y muestra
 *   un cartel de PELIGRO hasta que los ejes se estabilizan.
 * - Boton "APAGAR CONTROL": manda "CMD,OFF" al ESP32.  Tecla C: recalibrar.
 * - Guarda los eventos en eventos.csv (modo append).
 *
 * IMPORTANTE: cerrar el Monitor Serie de VS Code antes de abrir este programa.
 */
import processing.serial.*;

// ---------------- Configuracion ----------------
final String PUERTO_FIJO = "";          // Ej: "COM3". Vacio = buscar el ESP32 automaticamente
final int VELOCIDAD_SERIE = 115200;
final int TIMEOUT_PUERTO_MS = 4000;     // tiempo para probar cada puerto
final int TIMEOUT_DATOS_MS = 4000;      // sin datos durante este tiempo = conexion perdida
final int TIMEOUT_APAGADO_MS = 3000;    // espera la confirmacion de apagado


// Detector de movimientos bruscos (sensibilidad media)
final float UMBRAL_VELOCIDAD = 900;      // salta con un tirón rápido (centro a borde en ~0,11 s)
final float UMBRAL_VELOCIDAD_BAJA = 160; // vuelve a NORMAL apenas frenás el stick
final float UMBRAL_DISPERSION = 10;      // tolera pequeñas oscilaciones al centrar
final int VENTANA_MS = 1000;
final int BASE_DERIVADA_MS = 120;        // ventana corta para captar golpes secos
final int TIEMPO_ESTABLE_MS = 300;

// Escena 3D
final float SUELO_Y = 140;

// Estados de la aplicacion (maquina de estados)
final int ST_BUSCANDO_PUERTO = 0;
final int ST_NORMAL = 1;
final int ST_PELIGRO = 2;
final int ST_APAGANDO = 3;
final int ST_APAGADO = 4;

// ---------------- Variables globales ----------------
int estado = ST_BUSCANDO_PUERTO;
Serial puerto = null;
String[] listaPuertos = new String[0];
int indicePuerto = 0;
int tIntentoPuerto = 0;
int tUltimaLista = -5000;
int tUltimoDato = 0;
int tApagando = 0;
int ultimoMs = 0;
String nombrePuerto = "-";

Muestra ultima = new Muestra(0, 0, 0, 0, 0);
boolean btnIzqPres = false;
boolean btnDerPres = false;
int estadoControl = 0;      // 0 calibrando, 1 buscando telefono, 2 conectado

Dron dron;
DetectorBrusco detector;
Registro registro;
BotonUI botonApagar;
PFont fuente;

void setup() {
  size(1000, 650, P3D);
  surface.setTitle("Monitor de vuelo - Control de dron");
  fuente = createFont("Arial", 14, true);
  textFont(fuente);

  dron = new Dron();
  detector = new DetectorBrusco();
  registro = new Registro("eventos.csv");
  botonApagar = new BotonUI(20, 585, 300, 46, "APAGAR CONTROL", color(190, 40, 40));
  ultimoMs = millis();
  registro.evento("INICIO_APP");
}

void draw() {
  int ahora = millis();
  float dt = constrain((ahora - ultimoMs) / 1000.0, 0.001, 0.05);
  ultimoMs = ahora;

  gestionarPuerto();
  leerPuerto();
  verificarTimeouts();

  boolean activo = (estado == ST_NORMAL || estado == ST_PELIGRO || estado == ST_APAGANDO);
  dron.actualizar(dt, activo, ultima.throttle, ultima.yaw, ultima.pitch, ultima.roll);

  background(16, 20, 28);
  dibujarEscena3D();

  hint(DISABLE_DEPTH_TEST);
  noLights();
  dibujarInterfaz();
  hint(ENABLE_DEPTH_TEST);
}

// ======================= Comunicacion serie =======================

/** Busca el ESP32 probando los puertos serie uno por uno (solo en ST_BUSCANDO_PUERTO). */
void gestionarPuerto() {
  if (estado != ST_BUSCANDO_PUERTO) return;

  if (puerto == null) {
    if (millis() - tUltimaLista < 1000) return;
    tUltimaLista = millis();
    if (PUERTO_FIJO.length() > 0) listaPuertos = new String[] { PUERTO_FIJO };
    else listaPuertos = Serial.list();
    if (listaPuertos.length == 0) return;
    if (indicePuerto >= listaPuertos.length) indicePuerto = 0;
    try {
      puerto = new Serial(this, listaPuertos[indicePuerto], VELOCIDAD_SERIE);
      puerto.clear();
      tIntentoPuerto = millis();
    } catch (Exception e) {
      puerto = null;
      indicePuerto++;
    }
  } else if (millis() - tIntentoPuerto > TIMEOUT_PUERTO_MS) {
    cerrarPuerto();
    indicePuerto++;
  }
}

/** Cierra el puerto serie si esta abierto. */
void cerrarPuerto() {
  if (puerto != null) {
    puerto.stop();
    puerto = null;
  }
}

/** Lee todas las lineas disponibles (en el hilo de dibujo, sin problemas de concurrencia). */
void leerPuerto() {
  if (puerto == null) return;
  while (puerto.available() > 0) {
    String linea = puerto.readStringUntil('\n');
    if (linea == null) break;
    procesarLinea(trim(linea));
  }
}

/** Marca el puerto actual como el correcto la primera vez que llegan datos validos. */
void confirmarPuerto() {
  if (estado != ST_BUSCANDO_PUERTO) return;
  estado = ST_NORMAL;
  nombrePuerto = listaPuertos[indicePuerto];
  detector.reiniciar();
  registro.evento("PUERTO_CONECTADO," + nombrePuerto);
}

/** Interpreta una linea del ESP32: ejes ("J,...") o eventos ("EVT,..."). */
void procesarLinea(String linea) {
  if (linea.startsWith("J,")) {
    String[] p = split(linea, ',');
    if (p.length < 8) return;
    float thr, yw, pit, rol;
    try {
      thr = float(p[1]);
      yw = -float(p[2]);
      pit = float(p[3]);
      rol = float(p[4]);
      btnIzqPres = (int(p[5]) == 1);
      btnDerPres = (int(p[6]) == 1);
      estadoControl = int(p[7]);
    } catch (Exception e) {
      return;
    }
    if (Float.isNaN(thr) || Float.isNaN(yw) || Float.isNaN(pit) || Float.isNaN(rol)) return;

    tUltimoDato = millis();
    confirmarPuerto();
    ultima = new Muestra(millis(), thr, yw, pit, rol);

    if (estado == ST_NORMAL || estado == ST_PELIGRO) {
      detector.agregar(ultima);
      if (detector.peligro && estado == ST_NORMAL) {
        estado = ST_PELIGRO;
        registro.evento("PELIGRO_INICIO,velocidad=" + int(detector.velocidad));
      } else if (!detector.peligro && estado == ST_PELIGRO) {
        estado = ST_NORMAL;
        registro.evento("PELIGRO_FIN,pico=" + int(detector.velocidadPico));
      }
    }
  } else if (linea.startsWith("EVT,")) {
    String ev = linea.substring(4);
    tUltimoDato = millis();
    confirmarPuerto();
    if (ev.equals("APAGADO")) {
      estado = ST_APAGADO;
      ultima = new Muestra(millis(), 0, 0, 0, 0);
      detector.reiniciar();
      registro.evento("CONTROL_APAGADO");
    } else if (ev.equals("CALIBRANDO")) {
      estadoControl = 0;
      detector.reiniciar();
      if (estado == ST_APAGADO) {
        estado = ST_NORMAL;
        registro.evento("CONTROL_ENCENDIDO");
      }
    } else {
      registro.evento("BLUETOOTH," + ev);
    }
  }
}

/** Controla las perdidas de conexion y la espera de confirmacion de apagado. */
void verificarTimeouts() {
  if ((estado == ST_NORMAL || estado == ST_PELIGRO) && millis() - tUltimoDato > TIMEOUT_DATOS_MS) {
    registro.evento("SIN_DATOS");
    cerrarPuerto();
    detector.reiniciar();
    estado = ST_BUSCANDO_PUERTO;
  }
  if (estado == ST_APAGANDO && millis() - tApagando > TIMEOUT_APAGADO_MS) {
    estado = ST_NORMAL;
    registro.evento("APAGADO_SIN_RESPUESTA");
  }
}

/** Pide al ESP32 que se apague. */
void pedirApagado() {
  if (puerto == null) return;
  if (estado != ST_NORMAL && estado != ST_PELIGRO) return;
  puerto.write("CMD,OFF\n");
  estado = ST_APAGANDO;
  tApagando = millis();
  registro.evento("APAGAR_SOLICITADO");
}

// ======================= Entradas del usuario =======================

void mousePressed() {
  if (botonApagar.habilitado && botonApagar.contiene(mouseX, mouseY)) pedirApagado();
}

void keyPressed() {
  if ((key == 'c' || key == 'C') && puerto != null && (estado == ST_NORMAL || estado == ST_PELIGRO)) {
    puerto.write("CMD,CAL\n");
    registro.evento("RECALIBRAR");
  }
}

// ======================= Dibujo =======================

/** Dibuja el suelo, la sombra y el dron en 3D. */
void dibujarEscena3D() {
  lights();
  pushMatrix();
  translate(660, 345, 0);
  rotateX(-0.32);

  // suelo (grilla)
  stroke(45, 60, 80);
  strokeWeight(1);
  for (int i = -230; i <= 230; i += 46) {
    line(i, SUELO_Y, -230, i, SUELO_Y, 230);
    line(-230, SUELO_Y, i, 230, SUELO_Y, i);
  }

  // sombra
  pushMatrix();
  translate(dron.x, SUELO_Y - 1, dron.z);
  rotateX(HALF_PI);
  noStroke();
  fill(0, 0, 0, 110);
  float r = max(30, 80 - dron.alt * 0.18);
  ellipse(0, 0, r, r);
  popMatrix();

  dron.dibujar(estado == ST_PELIGRO);
  popMatrix();
}

/** Nombre del estado de la aplicacion. */
String nombreEstadoApp() {
  switch (estado) {
    case ST_BUSCANDO_PUERTO: return "BUSCANDO ESP32";
    case ST_NORMAL: return "NORMAL";
    case ST_PELIGRO: return "PELIGRO";
    case ST_APAGANDO: return "APAGANDO...";
    case ST_APAGADO: return "APAGADO";
  }
  return "?";
}

/** Color asociado al estado de la aplicacion. */
color colorEstadoApp() {
  switch (estado) {
    case ST_NORMAL: return color(40, 170, 90);
    case ST_PELIGRO: return color(210, 45, 45);
    case ST_APAGANDO: return color(220, 150, 30);
    default: return color(110, 115, 130);
  }
}

/** Dibuja toda la interfaz 2D (paneles, datos, boton, alertas). */
void dibujarInterfaz() {
  // ----- panel izquierdo -----
  noStroke();
  fill(24, 30, 42);
  rect(0, 0, 340, height);

  fill(235);
  textAlign(LEFT, TOP);
  textSize(18);
  text("MONITOR DE VUELO", 20, 14);
  fill(140);
  textSize(12);
  text("Puerto: " + nombrePuerto, 20, 38);

  dibujarPalanca(20, 78, 140, "Joystick izquierdo", ultima.yaw, ultima.throttle);
  dibujarPalanca(180, 78, 140, "Joystick derecho", ultima.roll, ultima.pitch);

  fill(200);
  textSize(12);
  textAlign(LEFT, TOP);
  text("X (yaw): " + int(ultima.yaw), 20, 226);
  text("Y (throttle): " + int(ultima.throttle), 20, 242);
  text("Boton: " + (btnIzqPres ? "PRESIONADO" : "libre"), 20, 258);
  text("X (roll): " + int(ultima.roll), 180, 226);
  text("Y (pitch): " + int(ultima.pitch), 180, 242);
  text("Boton: " + (btnDerPres ? "PRESIONADO" : "libre"), 180, 258);

  // ----- datos de vuelo -----
  encabezado("DATOS DE VUELO", 285);
  float rumbo = degrees(dron.yaw) % 360;
  if (rumbo < 0) rumbo += 360;
  float vel = sqrt(dron.vx * dron.vx + dron.vz * dron.vz) / 10.0;
  fill(200);
  text("Rumbo: " + nf(rumbo, 0, 0) + " grados", 20, 305);
  text("Altitud: " + nf(dron.alt / 10.0, 0, 1) + " m", 20, 321);
  text("Inclinacion: pitch " + nf(degrees(dron.pitch), 0, 0) + "  roll " + nf(degrees(dron.roll), 0, 0), 20, 337);
  text("Velocidad: " + nf(vel, 0, 1) + " m/s", 20, 353);

  // ----- estabilidad -----
  encabezado("ESTABILIDAD DE LOS JOYSTICKS", 380);
  float frac = constrain(detector.velocidad / (UMBRAL_VELOCIDAD * 1.5), 0, 1);
  fill(45, 52, 66);
  rect(20, 402, 300, 12, 4);
  fill(detector.velocidad > UMBRAL_VELOCIDAD ? color(210, 45, 45) : color(40, 170, 90));
  rect(20, 402, 300 * frac, 12, 4);
  stroke(255, 215, 0);
  float xl = 20 + 300 * (1 / 1.5);
  line(xl, 398, xl, 418);
  noStroke();
  fill(200);
  text("Velocidad de cambio: " + int(detector.velocidad) + " u/s (limite " + int(UMBRAL_VELOCIDAD) + ")", 20, 421);
  text("Dispersion: " + nf(detector.dispersion, 0, 1) + " (estable si < " + int(UMBRAL_DISPERSION) + ")", 20, 437);

  // ----- estado -----
  encabezado("ESTADO", 462);
  fill(200);
  text("Aplicacion: " + nombreEstadoApp(), 20, 482);
  String txtControl = "-";
  if (estado == ST_NORMAL || estado == ST_PELIGRO || estado == ST_APAGANDO) {
    if (estadoControl == 0) txtControl = "CALIBRANDO (no tocar los sticks)";
    else if (estadoControl == 1) txtControl = "BUSCANDO TELEFONO";
    else txtControl = "CONECTADO AL TELEFONO";
  }
  text("Control: " + txtControl, 20, 498);

  boolean ledVerde = false;
  boolean ledRojo = false;
  if (estado == ST_NORMAL || estado == ST_PELIGRO || estado == ST_APAGANDO) {
    ledVerde = (estadoControl == 0 || estadoControl == 2);
    ledRojo = (estadoControl == 0) || (estadoControl == 1 && (millis() / 400) % 2 == 0);
  }
  dibujarLed(28, 524, "LED verde (conectado)", color(40, 210, 90), ledVerde);
  dibujarLed(180, 524, "LED rojo (buscando)", color(230, 50, 50), ledRojo);

  // ----- eventos recientes (datos en memoria) -----
  fill(130);
  textSize(11);
  textAlign(LEFT, TOP);
  int n = registro.recientes.size();
  for (int i = 0; i < min(3, n); i++) {
    text(registro.recientes.get(n - 1 - i), 20, 540 + i * 14);
  }

  // ----- boton -----
  botonApagar.habilitado = (estado == ST_NORMAL || estado == ST_PELIGRO);
  botonApagar.dibujar();

  // ----- zona derecha -----
  color ce = colorEstadoApp();
  noStroke();
  fill(ce);
  rect(360, 14, 250, 34, 17);
  fill(255);
  textAlign(CENTER, CENTER);
  textSize(15);
  text("Estado: " + nombreEstadoApp(), 485, 31);

  fill(110);
  textAlign(LEFT, TOP);
  textSize(12);
  text("Tecla C = recalibrar el centro de los sticks", 360, 622);

  if (estado == ST_PELIGRO) dibujarAlertaPeligro();
  else if (estado == ST_BUSCANDO_PUERTO) dibujarMensajeCentral("BUSCANDO EL ESP32", mensajeBusqueda());
  else if (estado == ST_APAGANDO) dibujarMensajeCentral("APAGANDO EL CONTROL...", "Esperando la confirmacion del ESP32");
  else if (estado == ST_APAGADO) dibujarMensajeCentral("CONTROL APAGADO", "Para encenderlo: presione el boton de reset");
}

/** Texto de ayuda mientras se busca el puerto. */
String mensajeBusqueda() {
  if (puerto != null && indicePuerto < listaPuertos.length) {
    return "Probando " + listaPuertos[indicePuerto] + "...  (cerra el Monitor Serie de VS Code)";
  }
  if (listaPuertos.length == 0) return "No se detectan puertos serie. Conecta el ESP32 por USB.";
  return "Preparando...";
}
