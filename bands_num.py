#!/usr/bin/env python3
"""
Script para procesar un archivo de bandas.
El archivo de entrada (bands.dat) contiene:
  - Líneas de comentarios (inician con "#")
  - Líneas de datos con tres columnas separadas por espacios.
La separación en bloques se determina porque la primera columna se reinicia a 0.
En el archivo de salida (bands_num.dat), la tercera columna se reemplaza
por el número de bloque correspondiente (1 para el primer bloque, 2 para el segundo, etc.).

Uso:
    python process_bands.py
"""

def process_file(input_filename="bands.dat", output_filename="bands_num.dat"):
    current_block = 0

    # Abrir el archivo de entrada y leer todas las líneas
    with open(input_filename, "r") as fin:
        lines = fin.readlines()

    output_lines = []

    for line in lines:
        stripped_line = line.strip()
        # Si es línea vacía o de comentario, se escribe sin cambios.
        if not stripped_line or stripped_line.startswith("#"):
            output_lines.append(line)
            continue

        # Para líneas de datos, se espera que existan al menos tres columnas
        tokens = line.split()
        if len(tokens) < 3:
            # Si no se tienen tres tokens, se escribe la línea sin cambios
            output_lines.append(line)
            continue

        try:
            # Convertir el primer token en flotante
            k_val = float(tokens[0])
        except ValueError:
            # Si falla la conversión, se asume que no es una línea de datos
            output_lines.append(line)
            continue

        # Si el valor de k es 0, es inicio de nuevo bloque:
        if k_val == 0.0:
            current_block += 1

        # Reemplazar el tercer token por el número de bloque actual
        tokens[2] = str(current_block)

        # Reconstruir la línea con formato (separadas por espacios)
        new_line = "   ".join(tokens) + "\n"
        output_lines.append(new_line)

    # Guardar el resultado en el archivo de salida
    with open(output_filename, "w") as fout:
        fout.writelines(output_lines)

    print(f"Archivo procesado guardado como {output_filename}.")

if __name__ == "__main__":
    process_file()
