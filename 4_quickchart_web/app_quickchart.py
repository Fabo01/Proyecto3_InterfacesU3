# -*- coding: utf-8 -*-
# Servidor web Flask para consultar mediciones y generar graficas con QuickChart

import os
import sqlite3
import requests
from flask import Flask, jsonify, redirect, render_template_string

app = Flask(__name__)

# Ruta relativa a la base de datos generada por el servidor TCP de Lazarus
carpeta_base = os.path.dirname(os.path.abspath(__file__))
ruta_bd = os.path.abspath(os.path.join(carpeta_base, "..", "1_server_tcp_lazarus", "aire.db"))


def obtener_conexion_bd():
    # Abrimos la conexion a SQLite si el archivo existe
    if not os.path.exists(ruta_bd):
        return None
    try:
        conexion = sqlite3.connect(ruta_bd, timeout=3.0)
        return conexion
    except sqlite3.Error:
        return None


# Plantilla HTML para la interfaz web principal
plantilla_html = """
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Monitoreo MP 2.5 - QuickChart Flask</title>
    <style>
        :root {
            --primary: #1e3a8a;
            --primary-accent: #3b82f6;
            --success: #10b981;
            --warning: #f59e0b;
            --danger: #ef4444;
            --bg: #f8fafc;
            --card-bg: #ffffff;
            --text-dark: #1e293b;
            --text-muted: #64748b;
            --border: #e2e8f0;
        }
        * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; }
        body { background: var(--bg); color: var(--text-dark); padding: 24px 16px; }
        .container { max-width: 950px; margin: 0 auto; }
        .header { background: linear-gradient(135deg, #1e3a8a 0%, #0284c7 100%); color: white; padding: 28px; border-radius: 12px; margin-bottom: 24px; box-shadow: 0 4px 12px rgba(30, 58, 138, 0.15); }
        .header h1 { font-size: 24px; margin-bottom: 8px; }
        .header p { opacity: 0.9; font-size: 14px; }
        .grid-stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 16px; margin-bottom: 24px; }
        .card { background: var(--card-bg); padding: 20px; border-radius: 10px; border: 1px solid var(--border); box-shadow: 0 2px 4px rgba(0,0,0,0.04); }
        .card .title { font-size: 13px; color: var(--text-muted); text-transform: uppercase; font-weight: 600; margin-bottom: 6px; }
        .card .value { font-size: 26px; font-weight: bold; color: var(--text-dark); }
        .badge { display: inline-block; padding: 4px 10px; border-radius: 9999px; font-size: 12px; font-weight: 600; }
        .badge-ok { background: #dcfce7; color: #166534; }
        .badge-wait { background: #fef3c7; color: #92400e; }
        .actions { display: flex; gap: 12px; flex-wrap: wrap; margin-bottom: 24px; }
        .btn { display: inline-flex; align-items: center; gap: 8px; text-decoration: none; font-weight: 600; padding: 12px 22px; border-radius: 8px; transition: all 0.2s; cursor: pointer; border: none; font-size: 14px; }
        .btn-primary { background: var(--primary-accent); color: white; box-shadow: 0 2px 6px rgba(59, 130, 246, 0.3); }
        .btn-primary:hover { background: #2563eb; transform: translateY(-1px); }
        .btn-secondary { background: white; color: var(--text-dark); border: 1px solid var(--border); }
        .btn-secondary:hover { background: #f1f5f9; }
        .table-card { background: var(--card-bg); border-radius: 10px; border: 1px solid var(--border); overflow: hidden; box-shadow: 0 2px 4px rgba(0,0,0,0.04); }
        .table-header { padding: 16px 20px; border-bottom: 1px solid var(--border); display: flex; justify-content: space-between; align-items: center; }
        .table-header h2 { font-size: 16px; color: var(--text-dark); }
        .auto-refresh { font-size: 13px; color: var(--text-muted); display: flex; align-items: center; gap: 6px; }
        table { width: 100%; border-collapse: collapse; text-align: left; }
        th { background: #f8fafc; padding: 12px 20px; font-size: 12px; color: var(--text-muted); text-transform: uppercase; font-weight: 600; border-bottom: 1px solid var(--border); }
        td { padding: 12px 20px; font-size: 14px; border-bottom: 1px solid var(--border); }
        tr:last-child td { border-bottom: none; }
        tr:hover td { background: #f8fafc; }
        .val-badge { font-weight: bold; color: #b91c1c; background: #fee2e2; padding: 3px 8px; border-radius: 6px; }
        .empty-msg { padding: 32px; text-align: center; color: var(--text-muted); font-size: 14px; }
        .footer { margin-top: 24px; text-align: center; font-size: 12px; color: var(--text-muted); }
    </style>
</head>
<body>
    <div class="container">
        <header class="header">
            <h1>Proyecto #3: Visualizador Web QuickChart</h1>
            <p>Monitoreo de Material Particulado MP 2.5 um - Conexion SQLite (aire.db)</p>
        </header>

        <section class="grid-stats">
            <div class="card">
                <div class="title">Estado Base de Datos</div>
                <div>
                    {% if bd_conectada %}
                        <span class="badge badge-ok">CONECTADO</span>
                    {% else %}
                        <span class="badge badge-wait">ESPERANDO SERVIDOR</span>
                    {% endif %}
                </div>
                <div style="font-size: 11px; color: var(--text-muted); margin-top: 6px; word-break: break-all;">
                    {{ ruta_bd }}
                </div>
            </div>

            <div class="card">
                <div class="title">Total Mediciones en Tabla 'Aire'</div>
                <div class="value">{{ total_registros }}</div>
                <div style="font-size: 12px; color: var(--text-muted); margin-top: 4px;">muestras recibidas</div>
            </div>

            <div class="card">
                <div class="title">Ultimo Valor Registrado</div>
                <div class="value" style="color: #b91c1c;">
                    {% if ultimo_mp25 is not none %}
                        {{ ultimo_mp25 }} <span style="font-size: 16px; font-weight: normal;">ug/m3</span>
                    {% else %}
                        --
                    {% endif %}
                </div>
                <div style="font-size: 12px; color: var(--text-muted); margin-top: 4px;">
                    {% if ultima_fecha %}
                        {{ ultima_fecha }} {{ ultima_hora }}
                    {% else %}
                        Sin lecturas aun
                    {% endif %}
                </div>
            </div>
        </section>

        <section class="actions">
            <a class="btn btn-primary" href="/grafica" target="_blank">
                Abrir Grafica QuickChart.io
            </a>
            <a class="btn btn-secondary" href="/datos" target="_blank">
                Ver API JSON (/datos)
            </a>
        </section>

        <section class="table-card">
            <div class="table-header">
                <h2>Ultimas 15 Lecturas Registradas</h2>
                <div class="auto-refresh">
                    <label>
                        <input type="checkbox" id="chkRefresh" checked> Auto-recarga (3s)
                    </label>
                </div>
            </div>

            {% if filas %}
                <table>
                    <thead>
                        <tr>
                            <th>ID</th>
                            <th>Fecha</th>
                            <th>Hora</th>
                            <th>MP 2.5 (ug/m3)</th>
                        </tr>
                    </thead>
                    <tbody>
                        {% for f in filas %}
                        <tr>
                            <td>#{{ f[0] }}</td>
                            <td>{{ f[1] }}</td>
                            <td>{{ f[2] }}</td>
                            <td><span class="val-badge">{{ f[3] }} ug/m3</span></td>
                        </tr>
                        {% endfor %}
                    </tbody>
                </table>
            {% else %}
                <div class="empty-msg">
                    No hay mediciones en la tabla <code>Aire</code> todavia.<br>
                    Inicie el Servidor TCP en Lazarus (1_server_tcp_lazarus) y el Simulador Serial (2_simulador_serial).
                </div>
            {% endif %}
        </section>

        <footer class="footer">
            Proyecto #3 - Interfaces de Computadoras | Flask + SQLite + QuickChart API
        </footer>
    </div>

    <script>
        // Auto-refresco opcional cada 3 segundos si el checkbox esta activo
        setInterval(function() {
            var chk = document.getElementById('chkRefresh');
            if (chk && chk.checked) {
                window.location.reload();
            }
        }, 3000);
    </script>
</body>
</html>
"""


@app.route("/", methods=["GET"])
def index():
    # Pagina de inicio con resumen, tabla de mediciones y botones
    conexion = obtener_conexion_bd()
    bd_conectada = False
    total_registros = 0
    ultimo_mp25 = None
    ultima_fecha = None
    ultima_hora = None
    filas = []

    if conexion is not None:
        try:
            cursor = conexion.cursor()
            # Cantidad total de filas registradas
            cursor.execute("SELECT COUNT(*) FROM Aire")
            total_registros = cursor.fetchone()[0]

            # Obtenemos el ultimo valor guardado
            cursor.execute("SELECT fecha, hora, mp25 FROM Aire ORDER BY id DESC LIMIT 1")
            ultimo = cursor.fetchone()
            if ultimo:
                ultima_fecha, ultima_hora, ultimo_mp25 = ultimo

            # Obtenemos las ultimas 15 filas para mostrarlas en la tabla
            cursor.execute("SELECT id, fecha, hora, mp25 FROM Aire ORDER BY id DESC LIMIT 15")
            filas = cursor.fetchall()
            bd_conectada = True
        except sqlite3.OperationalError:
            # La tabla Aire aun no existe (servidor TCP aun no guarda registros)
            bd_conectada = False
        finally:
            conexion.close()

    return render_template_string(
        plantilla_html,
        bd_conectada=bd_conectada,
        ruta_bd=ruta_bd,
        total_registros=total_registros,
        ultimo_mp25=ultimo_mp25,
        ultima_fecha=ultima_fecha,
        ultima_hora=ultima_hora,
        filas=filas
    )


@app.route("/grafica", methods=["GET"])
def obtener_grafica():
    # Consulta las ultimas 20 lecturas de la tabla Aire y redirige a QuickChart.io
    conexion = obtener_conexion_bd()
    if conexion is None:
        return jsonify({
            "error": "La base de datos 'aire.db' no existe aun.",
            "sugerencia": "Ejecute el Servidor TCP en Lazarus para inicializar la base de datos."
        }), 404

    try:
        cursor = conexion.cursor()
        cursor.execute("SELECT fecha, hora, mp25 FROM Aire ORDER BY id DESC LIMIT 20")
        filas = cursor.fetchall()
    except sqlite3.OperationalError as error:
        return jsonify({
            "error": "La tabla 'Aire' aun no existe en la base de datos.",
            "detalle": str(error)
        }), 404
    finally:
        conexion.close()

    if not filas:
        return jsonify({
            "error": "No hay datos registrados aun en la tabla Aire.",
            "sugerencia": "Inicie el Simulador Serial para comenzar a transmitir mediciones."
        }), 404

    # Invertimos el orden para graficar cronologicamente de izquierda a derecha
    filas.reverse()
    tiempos = [f[1] for f in filas]
    valores = [f[2] for f in filas]

    # Configuracion de Chart.js enviada a QuickChart
    # Curva roja con puntos azules segun los requisitos
    configuracion_grafica = {
        "type": "line",
        "data": {
            "labels": tiempos,
            "datasets": [
                {
                    "label": "MP 2.5 (ug/m3)",
                    "data": valores,
                    "borderColor": "red",
                    "backgroundColor": "rgba(239, 68, 68, 0.15)",
                    "pointBackgroundColor": "blue",
                    "pointBorderColor": "blue",
                    "pointRadius": 5,
                    "fill": False,
                    "lineTension": 0.2
                }
            ]
        },
        "options": {
            "title": {
                "display": True,
                "text": "Monitoreo Material Particulado MP 2.5 um - Tabla Aire (SQLite)"
            },
            "scales": {
                "yAxes": [
                    {
                        "scaleLabel": {
                            "display": True,
                            "labelString": "Concentracion MP 2.5 (ug/m3)"
                        },
                        "ticks": {
                            "suggestedMin": 60,
                            "suggestedMax": 100
                        }
                    }
                ],
                "xAxes": [
                    {
                        "scaleLabel": {
                            "display": True,
                            "labelString": "Hora de Muestreo (1s)"
                        }
                    }
                ]
            }
        }
    }

    try:
        respuesta_qc = requests.post(
            "https://quickchart.io/chart/create",
            json={"chart": configuracion_grafica},
            timeout=5
        )

        if respuesta_qc.status_code != 200:
            return jsonify({
                "error": "Error al conectar con la API de QuickChart",
                "status_code": respuesta_qc.status_code,
                "respuesta": respuesta_qc.text
            }), 502

        url_grafica = respuesta_qc.json().get("url")
        if not url_grafica:
            return jsonify({"error": "Respuesta invalida de QuickChart (sin URL)"}), 502

        # Redirigimos a la URL generada por QuickChart
        return redirect(url_grafica, code=302)

    except requests.RequestException as error:
        return jsonify({
            "error": "Excepcion al conectar con el servicio web de QuickChart",
            "detalle": str(error)
        }), 502


@app.route("/datos", methods=["GET"])
def obtener_datos():
    # Devuelve las ultimas 30 lecturas de la tabla Aire en formato JSON
    conexion = obtener_conexion_bd()
    if conexion is None:
        return jsonify({"status": "esperando_db", "mensaje": "Base de datos aire.db no encontrada", "lecturas": []}), 200

    try:
        cursor = conexion.cursor()
        cursor.execute("SELECT id, fecha, hora, mp25 FROM Aire ORDER BY id DESC LIMIT 30")
        filas = cursor.fetchall()
        registros = [
            {"id": f[0], "fecha": f[1], "hora": f[2], "mp25": f[3]}
            for f in filas
        ]
        return jsonify({
            "status": "ok",
            "total_consultados": len(registros),
            "ruta_bd": ruta_bd,
            "lecturas": registros
        }), 200
    except sqlite3.OperationalError as error:
        return jsonify({"status": "esperando_tabla", "mensaje": str(error), "lecturas": []}), 200
    finally:
        conexion.close()


if __name__ == "__main__":
    print("Servidor web Flask iniciado.")
    print(f"Ruta base de datos: {ruta_bd}")
    print("Disponible en: http://127.0.0.1:5000/")
    app.run(host="127.0.0.1", port=5000, debug=True)
