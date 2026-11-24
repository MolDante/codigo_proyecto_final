/**
 * Registro.pde - Guarda eventos en un archivo CSV sin borrar los anteriores (modo append),
 * recupera el historial al iniciar y mantiene en memoria los ultimos eventos para
 * mostrarlos en pantalla.
 */
class Registro {
  String archivo;
  ArrayList<String> recientes = new ArrayList<String>();

  Registro(String nombre) {
    archivo = sketchPath(nombre);
    cargarHistorial();
  }

  /** Recupera los ultimos 20 eventos guardados en ejecuciones anteriores. */
  void cargarHistorial() {
    String[] previas = loadStrings(archivo);   // null si el archivo todavia no existe
    if (previas == null) return;
    int desde = max(0, previas.length - 20);
    for (int i = desde; i < previas.length; i++) {
      String l = previas[i];
      // formato guardado: "aaaa-mm-dd hh:mm:ss,evento"
      if (l.length() > 20) recientes.add(l.substring(11, 19) + " " + l.substring(20));
    }
  }

  /** Agrega una linea "fecha hora,evento" al final del archivo, conservando lo anterior. */
  void evento(String texto) {
    String fecha = nf(year(), 4) + "-" + nf(month(), 2) + "-" + nf(day(), 2);
    String hora = nf(hour(), 2) + ":" + nf(minute(), 2) + ":" + nf(second(), 2);
    String linea = fecha + " " + hora + "," + texto;

    String[] previas = loadStrings(archivo);
    if (previas == null) previas = new String[0];
    saveStrings(archivo, append(previas, linea));

    recientes.add(hora + " " + texto);
    if (recientes.size() > 20) recientes.remove(0);
  }
}
