# =============================================================================
#  Makefile de simulação - rodar de dentro da pasta sim/
#
#    make cpu          processador RV32I (testbench unitário, modo texto)
#    make cpu-waves    idem, gravando formas de onda e abrindo o SimVision
#    make clean        apaga os arquivos gerados pelo simulador
#    make accel        malha sistólica 2×2 e 4×4
#
#  Simulador padrão: Xcelium (xrun). Para usar o Icarus Verilog:
#    make cpu SIM=iverilog
# =============================================================================

SIM       ?= xrun
XRUN_OPTS  = -timescale 1ns/1ps -access +rwc

CPU_HEX    = ../sw/cpu_tests/imem.hex

VEC_ROOT   = ../verif/unit/accel/vec_

.PHONY: cpu cpu-waves clean accel accel-2 accel-4 accel-waves

# a imem lê "imem.hex" da pasta onde a simulação roda
imem.hex: $(CPU_HEX)
	cp $(CPU_HEX) imem.hex

cpu: imem.hex
ifeq ($(SIM),iverilog)
	iverilog -g2005 -o cpu.vvp -c filelists/cpu.f
	vvp -n cpu.vvp | tee cpu.log
else
	xrun $(XRUN_OPTS) -f filelists/cpu.f -top tb_riscv -l cpu.log
endif

cpu-waves: imem.hex
	xrun $(XRUN_OPTS) -f filelists/cpu.f -top tb_riscv -l cpu.log -input probe.tcl
	simvision waves.shm &

clean:
	rm -rf xcelium.d waves.shm .simvision *.log *.history *.key *.vvp imem.hex

accel: accel-2 accel-4

accel-2 accel-4: accel-%:
ifeq ($(SIM),iverilog)
	iverilog -g2005 -o accel_$*.vvp -c filelists/accel.f \
	  -P tb_systolic.ARRAY_SIZE=$* -P 'tb_systolic.VEC_DIR="$(VEC_ROOT)$*x$*"'
	vvp -n accel_$*.vvp | tee accel_$*.log
else
	xrun $(XRUN_OPTS) -f filelists/accel.f -top tb_systolic -l accel_$*.log \
	  -defparam tb_systolic.ARRAY_SIZE=$* -defparam 'tb_systolic.VEC_DIR="$(VEC_ROOT)$*x$*"'
endif

accel-waves:
	xrun $(XRUN_OPTS) -f filelists/accel.f -top tb_systolic -l accel_2.log \
	  -defparam tb_systolic.ARRAY_SIZE=2 -defparam 'tb_systolic.VEC_DIR="$(VEC_ROOT)2x2"' \
	  -input probe.tcl
	simvision waves.shm &

