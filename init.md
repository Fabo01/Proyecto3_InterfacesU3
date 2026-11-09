# Guía de Inicialización y Flujo de Ejecución (`init.md`)

Este documento explica paso a paso cómo preparar y levantar todos los componentes del **Proyecto #3**, el orden en que deben iniciarse y **por qué** se hace cada paso dentro del flujo de datos.

---

## 1. Entendiendo el Flujo antes de Iniciar

Cuando el proyecto está corriendo, un dato nace cada 1 segundo y recorre este camino en cadena:

```text
[1. Python: simulador_serial.py]
       │  (Genera MP 2.5 con Normal(80,5) y lo escribe en COM2 cada 1 seg)
       ▼
[2. VSPE: Connector en COM2]
       │  (Puente virtual que permite a Python y Lazarus usar COM2 a la vez)
       ▼
[3. Lazarus GUI: visor_mp25]
       │  (Lee COM2 -> mueve la curva a la izquierda -> manda el valor al puerto TCP 9000)
       ▼
[4. Lazarus Consola: server_tcp.exe]
       │  (Escucha el puerto 9000 -> muestra en consola -> guarda Fecha, Hora y MP2.5 en SQLite)
       ▼
[5. Base de Datos: 1_server_tcp_lazarus/aire.db (Tabla Aire en modo WAL)]
       ├──► [HeidiSQL 12.3 Portable] (Lee aire.db en vivo apretando F5)
       └──► [Flask: app_quickchart.py] (Lee aire.db y grafica en QuickChart.io)
```

---

## 2. Preparación en un Equipo Nuevo (Notebook) — 1 sola vez

Si acabas de prender el notebook para preparar la defensa:

1. **Programas necesarios:**
   - **Python 3** y **Git**
   - **VSPE** (*Virtual Serial Port Emulator*)
   - **Lazarus IDE (64 bits)** con el paquete **`LazSerial`** instalado (*Paquete $\rightarrow$ Administrador de Paquetes en Línea $\rightarrow$ buscar `LazSerial` $\rightarrow$ Instalar*).
   - **HeidiSQL 12.3 Portable** (descomprimido).

2. **Clonar el repositorio e instalar las librerías de Python:**
   ```powershell
   git clone https://github.com/Fabo01/Proyecto3_InterfacesU3.git
   cd Proyecto3_InterfacesU3
   pip install -r requirements.txt
   ```

---

## 3. Secuencia Paso a Paso para Inicializar Todo

Sigue este orden para que cada programa encuentre listo el recurso que necesita:

### Paso 1: Crear y activar el puerto `COM2` en VSPE
1. Abre **VSPE**.
2. Ve a **Device $\rightarrow$ Create...** (ícono de la estrella con el signo `+`).
3. En *Device type* selecciona **`Connector`** y presiona **Next**.
4. En *Virtual serial port* elige **`COM2`** y presiona **Finish**.
5. Presiona el botón verde de **Play** arriba (*Start emulation*) para que el estado diga **`OK` / `Ready`**.

> **¿Por qué se hace esto primero?**  
> En Windows, un puerto serial físico se bloquea apenas lo abre un programa. El dispositivo `Connector` de VSPE crea el puerto virtual `COM2` y permite que el simulador de Python (que escribe) y el visor de Lazarus (que lee) estén conectados al mismo `COM2` al mismo tiempo sin tirarse error de acceso denegado.

---

### Paso 2: Iniciar el Servidor TCP en Consola (`1_server_tcp_lazarus`)
Como en el IDE de Lazarus solo puedes tener un proyecto abierto a la vez, lo más cómodo es dejar corriendo el ejecutable del servidor TCP en una terminal de PowerShell (y dejar el IDE libre para mostrar el visor gráfico):

1. Si estás en el notebook recién clonado y aún no existe `server_tcp.exe`, compílalo una vez (con Lazarus o por terminal):
   ```powershell
   C:\lazarus\fpc\3.2.2\bin\x86_64-win64\fpc.exe -O2 -Mobjfpc -Sh "1_server_tcp_lazarus\server_tcp.lpr"
   ```
2. Ejecuta el servidor en tu primera terminal:
   ```powershell
   cd 1_server_tcp_lazarus
   .\server_tcp.exe
   ```
3. Verás en consola:
   ```text
   Servidor TCP Lazarus iniciado en el puerto 9000...
   Base de datos SQLite lista en: ...\1_server_tcp_lazarus\aire.db
   ```
   **Deja esa terminal abierta.**

> **¿Por qué se inicia antes de mandar datos?**  
> Porque al arrancar, `server_tcp.exe` crea automáticamente el archivo `aire.db`, crea la tabla `Aire (id, fecha, hora, mp25)`, activa el modo concurrente `WAL` y deja abierto el puerto TCP `9000` esperando lo que le mande el visor.

---

### Paso 3: Abrir el Visor Gráfico en Lazarus IDE (`3_visor_mp25_lazarus`)
1. Abre **Lazarus IDE**.
2. Ve a **Proyecto $\rightarrow$ Abrir proyecto...** y selecciona `3_visor_mp25_lazarus\visor_mp25.lpi`.
3. Presiona **F9** (o el botón verde *Ejecutar*).
4. Se abrirá la ventana **"By Alberto Caro"**. Arriba verás que las casillas **`COM2 On/Off`** y **`TCP Server On/Off`** ya parten activadas solas y el estado dice:
   `COM2: Conectado | Esperando datos... | TCP: Listo`.

> **¿Por qué parte conectado solo?**  
> En `FormCreate` dejamos ambas casillas activas por defecto y un `TimerReconexion` que reintenta abrir `COM2` cada 2 segundos si aún no estaba listo, para no perder tiempo configurando a mano en la defensa.

---

### Paso 4: Iniciar el Simulador Serial en Python (`2_simulador_serial`)
Abre una **segunda terminal** de PowerShell y ejecuta:

```powershell
cd 2_simulador_serial
python simulador_serial.py
```

Apenas arranque, cada **1 segundo** verás todo el flujo funcionando en paralelo:
1. **En la terminal de Python:** Muestra el valor generado con Distribución Normal(80, 5) (`Muestra 1: MP 2.5 = 81 ug/m3`).
2. **En la ventana de Lazarus:** La curva roja avanza un puesto hacia la izquierda (*Scrolling Left* de `0` a `29`). Ahí mismo puedes probar los 3 botones:
   - **`Click`** (paleta abajo a la derecha): rota entre los 6 paisajes de fondo (`img1.png` a `img6.png`).
   - **`On/off`** (arriba a la derecha): activa o desactiva la grilla punteada.
   - **`Save`** (cámara arriba a la derecha): guarda la foto del gráfico en `3_visor_mp25_lazarus\captura.png`.
3. **En la consola del Servidor TCP:** Aparece cada fila guardada (`Registro #1 | Fecha: ... | Hora: ... | MP 2.5: 81 ug/m3 (Guardado en Tabla Aire)`).

---

### Paso 5: Ver la Base de Datos en Tiempo Real con HeidiSQL 12.3
Con los datos ya corriendo y guardándose en `aire.db`:

1. Abre **`heidisql.exe`** (en tu carpeta `HeidiSQL`).
2. En la ventana *Administrador de sesiones*, haz clic abajo a la izquierda en **`Nueva`**.
3. A la derecha, cambia **`Tipo de red`** a **`SQLite`**.
4. En **`Librería`** verifica que apunte a `sqlite3.dll` (de la carpeta de HeidiSQL o de `1_server_tcp_lazarus\sqlite3.dll`).
5. En **`Archivo de base de datos`**, haz clic en la carpetita de la derecha y selecciona:
   `1_server_tcp_lazarus\aire.db`
6. Haz clic en **`Abrir`**.
7. En el panel izquierdo despliega **`aire`** $\rightarrow$ haz clic en la tabla **`Aire`** y arriba entra a la pestaña **`Datos`**.
8. Cada vez que presiones **`F5`** (o ejecutes en la pestaña *Consulta* `SELECT * FROM Aire ORDER BY id DESC LIMIT 20;`), verás las filas nuevas entrando segundo a segundo.

> **¿Por qué HeidiSQL puede leer `aire.db` mientras el servidor TCP escribe cada segundo?**  
> Porque el servidor TCP configuró SQLite con `PRAGMA journal_mode=WAL;`. Sin el modo `WAL`, SQLite bloquearía el archivo al escribir y HeidiSQL arrojaría el error `database is locked`.

---

### Paso 6 (Complementario): Gráfica en la Nube con Flask y QuickChart.io (`4_quickchart_web`)
Si durante la defensa quieres mostrar también la gráfica web de la clase del 3 de noviembre:

1. Abre una **tercera terminal** y ejecuta:
   ```powershell
   cd 4_quickchart_web
   python app_quickchart.py
   ```
2. Abre en tu navegador:
   - **Panel con tabla en vivo:** http://127.0.0.1:5000/
   - **Gráfica directa en QuickChart.io:** http://127.0.0.1:5000/grafica
   - **Datos en JSON:** http://127.0.0.1:5000/datos
