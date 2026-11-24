# Control de dron con ESP32 (Informática II - Tema 9)

Control de dron con **2 joysticks y un ESP32**. Funciona de dos formas a la vez:

1. **Bluetooth (BLE):** el ESP32 se presenta como un gamepad para el celular (simulador FeelFPV).
2. **USB (serie):** envía los datos a una interfaz en **Processing** que muestra los datos de vuelo,
   un dron simulado en 3D y un cartel de peligro ante movimientos bruscos de los joysticks.

## Estructura
- `arduino/` : proyecto PlatformIO para el ESP32 (`src/main.cpp` + librería propia en `lib/ControlDron`).
- `processing/DronMonitor/` : interfaz en Processing (varias pestañas/archivos).

## Conexiones
| Componente | Pin del módulo | Pin del ESP32 |
|---|---|---|
| Joystick izquierdo | GND / +5V / VRx / VRy / SW | GND / 3V3 / D32 (yaw) / D33 (throttle) / D25 |
| Joystick derecho | GND / +5V / VRx / VRy / SW | GND / 3V3 / D34 (roll) / D35 (pitch) / D26 |
| LED verde (conectado) | ánodo, con resistencia de 220 Ω | D18 (cátodo a GND) |
| LED rojo (buscando) | ánodo, con resistencia de 220 Ω | D16 (cátodo a GND) |

## Estados del ESP32
| Estado | LEDs |
|---|---|
| CALIBRANDO (1,5 s, sin tocar los sticks) | rojo y verde encendidos |
| BUSCANDO teléfono | rojo parpadeando |
| CONECTADO al teléfono | verde fijo |

## Protocolo serie (115200 baudios)
- ESP32 → PC: `J,throttle,yaw,pitch,roll,btn1,btn2,estado` y `EVT,<estado>`
- PC → ESP32: `CMD,OFF` (apagar) y `CMD,CAL` (recalibrar)

## Cómo usarlo
1. Abrir `arduino/` con VS Code + PlatformIO, compilar y subir al ESP32.
2. Emparejar el celular con "Dron Control UTN" (Bluetooth).
3. Cerrar el Monitor Serie y abrir `processing/DronMonitor/DronMonitor.pde` en Processing.

## Archivos
La interfaz guarda los eventos (conexión, peligro, apagado) en `eventos.csv` en modo append.
