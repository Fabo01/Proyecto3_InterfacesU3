# Proyecto #3 (Unidad III) — Interfaces Gráficas (INFO1128)

Sistema de monitoreo y visualización en tiempo real para **Material Particulado fino ($\text{MP}_{2.5}\ \mu\text{g/m}^3$)** desarrollado con **Lazarus Object Pascal** (`TAChart`, `TLazSerial` y `WinSock2`), **Python** (`pyserial`, `Flask` y **QuickChart.io**), **SQLite3** (modo concurrente `WAL`) e inspección en vivo mediante **HeidiSQL 12.3 Portable**.

- **Asignatura:** Interfaces Gráficas (INFO1128) — Universidad Católica de Temuco
- **Profesor:** Alberto Caro | **Ayudante:** Daniela Romero
- **Autor:** Fabián García

---

## Estructura del Repositorio

```text
Proyecto3_InterfacesU3/
├── 1_server_tcp_lazarus/
│   ├── server_tcp.lpr            # Servidor TCP/IP en modo consola (WinSock2 + SQLite3)
│   ├── server_tcp.lpi            # Configuración del proyecto de consola en Lazarus
│   └── sqlite3.dll               # Librería dinámica SQLite3 de 64 bits
├── 2_simulador_serial/
│   └── simulador_serial.py       # Emulador de sensor MP 2.5 con Distribución Normal(80, 5)
├── 3_visor_mp25_lazarus/
│   ├── visor_mp25.lpr            # Programa principal de la interfaz gráfica
│   ├── visor_mp25.lpi            # Proyecto Lazarus (TLazSerial, TAChartLazarusPkg, LCL)
│   ├── main.pas                  # Lógica del visor: Scrolling Left (0..29), fondos y cliente TCP
│   ├── main.lfm                  # Diseño del formulario (TChart y botones Save, On/off, Click)
│   ├── img1.png .. img6.png      # 6 paisajes de fondo intercambiables en tiempo real
│   ├── camara.png, pale.png      # Íconos de los botones Save y Click
│   ├── f02.bmp, sms2.bmp         # Ícono del botón On/off e ícono principal de la ventana
│   └── capturas/                 # Carpeta de exportación de capturas PNG del gráfico
├── 4_quickchart_web/
│   └── app_quickchart.py         # Servidor web Flask (Puerto 5000) integrado con QuickChart.io
├── init.md                       # Guía detallada de inicialización, orden de arranque y flujo
├── informe_defensa.tex           # Código fuente en LaTeX del informe de arquitectura y estudio
├── Interfaces_3.pdf              # Informe compilado en PDF para estudio y defensa
├── README.md                     # Descripción general y arquitectura del proyecto
└── requirements.txt              # Dependencias de Python (pyserial, flask, requests)
```

---

## Descripción de los Módulos

1. **Simulador Serial (`2_simulador_serial/simulador_serial.py`):**
   Modela la lectura de un sensor de material particulado generando muestras enteras cada `1.0` segundo mediante una **Distribución Normal de media 80 y desviación estándar 5** (`random.gauss(80, 5)`), transmitiéndolas por el puerto `COM2` a `9600 Bps, 8N1`.

2. **Visor Gráfico en Lazarus (`3_visor_mp25_lazarus/`):**
   Interfaz gráfica compilada que recibe las tramas seriales por `COM2` usando `TLazSerial` y grafica en tiempo real una ventana móvil de 30 muestras (`0..29`) con desplazamiento continuo hacia la izquierda (**Scrolling Left**). Incorpora:
   - Configuración completa de `TChart` y `TLineSeries` (`Legend`, `LinePen`, `Pointer`, `Marks`, `Frame`, `LabelBrush` y escalas fijas `Extent`).
   - Renderizado de 6 fondos dinámicos (`img1.png` a `img6.png`) en el evento `OnAfterDrawBackWall` optimizado con caché `TBitmap` en memoria RAM.
   - Controles interactivos con `Hint` activo: **`Save`** (exporta `captura.png`), **`On/off`** (activa/desactiva la grilla) y **`Click`** (rota el paisaje de fondo).
   - Cliente socket TCP no bloqueante (`WinSock2`) que retransmite cada lectura recibida hacia `127.0.0.1:9000`.

3. **Servidor TCP/IP en Modo Consola (`1_server_tcp_lazarus/`):**
   Servidor compilado en Free Pascal / Lazarus que escucha en el puerto TCP `9000`, imprime en consola cada medición entrante y la almacena con la fecha y hora exacta del sistema en la base de datos SQLite **`aire.db`** (tabla **`Aire`**), operando en modo `WAL` (*Write-Ahead Logging*) para permitir lecturas en tiempo real desde **HeidiSQL 12.3** sin bloqueos.

4. **Visualizador Web con QuickChart (`4_quickchart_web/app_quickchart.py`):**
   Servidor web en Flask (puerto `5000`) que consulta la tabla `Aire` de `aire.db`, despliega un tablero en vivo en `/` y genera gráficas en la nube mediante redirección a la API de **QuickChart.io** en `/grafica`.

---

## Contratos de Comunicación entre Módulos

| Tramo | Medio / Protocolo | Formato / Trama | Configuración |
| :--- | :--- | :--- | :--- |
| **Python $\rightarrow$ Visor Lazarus** | Serial Virtual (`COM2` en VSPE) | `<valor_mp25>\r\n` (ASCII) | 9600 Bps, 8N1, 1 muestra/seg |
| **Visor Lazarus $\rightarrow$ Server TCP** | Socket TCP/IP (`127.0.0.1:9000`) | `<valor_mp25>\n` | Socket no bloqueante en tiempo real |
| **Server TCP $\rightarrow$ SQLite3** | `TSQLite3Connection` (`aire.db`) | `INSERT INTO Aire (fecha, hora, mp25)` | Modo `WAL` concurrente |
| **HeidiSQL $\rightarrow$ SQLite3** | Librería nativa `sqlite3.dll` (64-bit) | `SELECT * FROM Aire` | Inspección en tiempo real (`F5`) |
| **Flask $\rightarrow$ QuickChart.io** | HTTPS REST API (`POST`) | JSON `Chart.js` (últimas 20 muestras) | Redirección HTTP `302` en `/grafica` |

---

## Documentación de Puesta en Marcha y Defensa

- **[`init.md`](./init.md):** Guía paso a paso para clonar, configurar e inicializar todas las partes del proyecto explicando el porqué de cada paso y el flujo de datos.
- **[`Interfaces_3.pdf`](./Interfaces_3.pdf) / [`informe_defensa.tex`](./informe_defensa.tex):** Informe de arquitectura, flujos y funcionamiento interno para el estudio y defensa del proyecto.
