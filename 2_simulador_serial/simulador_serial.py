# -*- coding: utf-8 -*-
# Simulador de sensor de material particulado MP 2.5 por puerto serial

import sys
import time
import random
import serial


def main():
    # Determinamos el puerto serial (por defecto COM2 o recibido por argumento)
    nombre_puerto = sys.argv[1] if len(sys.argv) > 1 else "COM2"

    # Intentamos abrir el puerto serial
    try:
        puerto = serial.Serial(
            port=nombre_puerto,
            baudrate=9600,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=1
        )
    except serial.SerialException as error:
        print(f"Error al abrir {nombre_puerto}: {error}")
        print("Revisa que el Connector en COM2 este activo en VSPE.")
        sys.exit(1)

    print(f"Conectado a {nombre_puerto} a 9600 baudios (8N1).")
    print("Transmitiendo datos cada 1 segundo. Presiona Ctrl+C para salir.\n")

    contador = 1
    try:
        while True:
            # Generamos el valor de MP 2.5 con distribucion normal de media 80 y desviacion 5
            valor_mp25 = int(round(random.gauss(80, 5)))
            if valor_mp25 < 0:
                valor_mp25 = 0

            # Preparamos la trama terminada en salto de linea y la enviamos
            texto_trama = f"{valor_mp25}\r\n".encode("utf-8")
            puerto.write(texto_trama)
            puerto.flush()

            print(f"Muestra {contador}: MP 2.5 = {valor_mp25} ug/m3")

            contador += 1
            time.sleep(1.0)

    except KeyboardInterrupt:
        print("\nTransmision detenida por el usuario.")
    finally:
        if 'puerto' in locals() and puerto.is_open:
            puerto.close()
            print(f"Puerto {nombre_puerto} cerrado.")


if __name__ == "__main__":
    main()
