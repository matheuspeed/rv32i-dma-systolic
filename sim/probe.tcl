# Grava todas as formas de onda do testbench (inclusive memórias) para o SimVision.
# Usado por "make cpu-waves". Depois: simvision waves.shm
database -open waves -shm -default
probe -create -shm -all -depth all -memories
run
exit
