#!/bin/bash

echo "=== Iniciando procesamiento de datos ==="

# ============================================================
# 📌 Archivos necesarios para ejecutar este script:
# ------------------------------------------------------------
# - aGNRP-13.KP                # Puntos de k
# - aGNRP-13.EIG               # Valores propios de los estados electrónicos
# - aGNRP-13.bands             # Archivo de bandas electrónicas
# - aGNRP-13.fullBZ.WFSX       # Funciones de onda completas en la zona de Brillouin
# - aGNRP-13.bands.WFSX        # Funciones de onda para las bandas seleccionadas
# - aGNRP-13prop.C.gga_s.EIGFAT  # Archivo EIGFAT para el orbital s
# - aGNRP-13prop.C.gga_px.EIGFAT # Archivo EIGFAT para el orbital px
# - aGNRP-13prop.C.gga_py.EIGFAT # Archivo EIGFAT para el orbital py
# - aGNRP-13prop.C.gga_pz.EIGFAT # Archivo EIGFAT para el orbital pz
# - bands.gplot                # Script de Gnuplot para la estructura de bandas
# - dos.gplot                  # Script de Gnuplot para la DOS
# - pdos.gplot                 # Script de Gnuplot para la PDOS
# - fatbands.gplot             # Script de Gnuplot para las Fat Bands
# ============================================================

# ========================
# 🔹 PASO 1: Cálculo de DOS
# ========================
echo "📌 Calculando DOS..."
Eig2DOS -f -e -25 -E 25 -s 0.2 -k aGNRP-13.KP aGNRP-13.EIG > dos
gnuplot dos.gplot

# Cálculo de la DOS usando el .DOS
gnuplot DOS.gplot 

# ============================
# 🔹 PASO 2: Cálculo de Bandas
# ============================
echo "📌 Generando estructura de bandas..."
gnubands -o bands.dat -F -e -25 -E 25 aGNRP-13.bands # Creamos el archivo bands.dat
python bands_num.py                                  # Numeramos las bandas en el archivo bands_num.dat 
gnuplot bands.gplot

# ===========================
# 🔹 PASO 3: Cálculo de PDOS
# ===========================
echo "📌 Calculando PDOS..."
#ln -sf aGNRP-13.fullBZ.WFSX aGNRP-13.WFSX
#mprop -n 2000 -m -25 -M 25 -s 0.5 aGNRP-13prop
#gnuplot pdos.gplot

# Segundo método usando fmpdos (ejecutar mínimo 2 veces si es la primera vez)
./fmpdos.sh         # Requiere del archivo aGNRP-13.PDOS
gnuplot fmpdos.gplot


# ===========================
# 🔹 PASO 4: Fat Bands
# ===========================
echo "📌 Procesando Fat Bands..."
ln -sf aGNRP-13.bands.WFSX aGNRP-13.WFSX
# El siguiente necesita de inputs .prop .HSX y .WFSX
fat -b 1 -B 200 aGNRP-13prop 

# 📌 Convertir archivos EIGFAT a datos para Gnuplot
echo "📌 Convirtiendo archivos EIGFAT a formato .dat..."
eigfat2plot aGNRP-13prop.C.gga_s.EIGFAT > C_s.dat
eigfat2plot aGNRP-13prop.C.gga_px.EIGFAT > C_px.dat
eigfat2plot aGNRP-13prop.C.gga_py.EIGFAT > C_py.dat
eigfat2plot aGNRP-13prop.C.gga_pz.EIGFAT > C_pz.dat

gnuplot fatbands.gplot


echo "🎉 === Proceso completado. Los gráficos han sido generados. === 🎉"
