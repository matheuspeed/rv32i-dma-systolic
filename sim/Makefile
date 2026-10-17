# =============================================================================
#  Makefile de simulação - rodar de dentro da pasta sim/
#
#    make cpu          processador RV32I (testbench unitário, modo texto)
#    make cpu-waves    idem, gravando formas de onda e abrindo o SimVision
#    make clean        apaga os arquivos gerados pelo simulador
#
#  Simulador padrão: Xcelium (xrun). Para usar o Icarus Verilog:
#    make cpu SIM=iverilog
# =============================================================================

SIM       ?= xrun
XRUN_OPTS  = -timescale 1ns/1ps -access +rwc

CPU_HEX    = ../sw/cpu_tests/imem.hex

.PHONY: cpu cpu-waves clean

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
