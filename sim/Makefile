# =============================================================================
#  Makefile de simulação - rodar de dentro da pasta sim/
#
#    make cpu          processador RV32I (testbench unitário, modo texto)
#    make cpu-waves    idem, gravando formas de onda e abrindo o SimVision
#    make clean        apaga os arquivos gerados pelo simulador
#    make accel        malha sistólica 2×2 e 4×4
#    make accel-waves  malha 2×2, gravando formas de onda e abrindo o SimVision
#    make mem          memória de dados dual-port (testbench unitário)
#    make accel-top    wrapper do acelerador (buffers + controle) 2×2 e 4×4
#    make dma          DMA + memória + acelerador sem CPU (3 vetores: basic, tiled, tiled-s4)
#
#  Simulador padrão: Xcelium (xrun). Para usar o Icarus Verilog:
#    make cpu SIM=iverilog
# =============================================================================

SIM       ?= xrun
XRUN_OPTS  = -timescale 1ns/1ps -access +rwc

CPU_HEX    = ../sw/cpu_tests/imem.hex

VEC_ROOT   = ../verif/unit/accel/vec_

DMA_VEC = ../verif/unit/dma
DMA_RUN = xrun $(XRUN_OPTS) -f filelists/dma.f -top tb_dma

.PHONY: cpu cpu-waves clean accel accel-2 accel-4 accel-waves mem accel-top accel-top-2 accel-top-4 dma dma-basic dma-tiled dma-tiled-s4

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
	rm -rf xcelium.d waves.shm .simvision cov_work *.log *.history *.key *.vvp imem.hex

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

mem:
ifeq ($(SIM),iverilog)
	iverilog -g2005 -o mem.vvp -c filelists/mem.f
	vvp -n mem.vvp | tee mem.log
else
	xrun $(XRUN_OPTS) -f filelists/mem.f -top tb_dmem_dp -l mem.log
endif

accel-top: accel-top-2 accel-top-4

accel-top-2 accel-top-4: accel-top-%:
ifeq ($(SIM),iverilog)
	iverilog -g2005 -o accel_top_$*.vvp -c filelists/accel_top.f \
	  -P tb_accel_top.ARRAY_SIZE=$* -P 'tb_accel_top.VEC_DIR="$(VEC_ROOT)$*x$*"'
	vvp -n accel_top_$*.vvp | tee accel_top_$*.log
else
	xrun $(XRUN_OPTS) -f filelists/accel_top.f -top tb_accel_top -l accel_top_$*.log \
	  -defparam tb_accel_top.ARRAY_SIZE=$* -defparam 'tb_accel_top.VEC_DIR="$(VEC_ROOT)$*x$*"'
endif

dma: dma-basic dma-tiled dma-tiled-s4

dma-basic:
	$(DMA_RUN) -l dma_basic.log -defparam tb_dma.ARRAY_SIZE=2 \
	  -defparam tb_dma.M=2 -defparam tb_dma.N=2 -defparam tb_dma.K=8 \
	  -defparam 'tb_dma.VEC_DIR="$(DMA_VEC)/vec_dma_basic"'

dma-tiled:
	$(DMA_RUN) -l dma_tiled.log -defparam tb_dma.ARRAY_SIZE=2 \
	  -defparam tb_dma.M=4 -defparam tb_dma.N=4 -defparam tb_dma.K=24 \
	  -defparam 'tb_dma.VEC_DIR="$(DMA_VEC)/vec_dma_tiled"'

dma-tiled-s4:
	$(DMA_RUN) -l dma_tiled_s4.log -defparam tb_dma.ARRAY_SIZE=4 \
	  -defparam tb_dma.M=8 -defparam tb_dma.N=8 -defparam tb_dma.K=24 \
	  -defparam 'tb_dma.VEC_DIR="$(DMA_VEC)/vec_dma_tiled_s4"'

ARRAY_SIZE ?= 4
UVM_TEST   ?= soc_directed_test
SEED       ?= 1
REGRESS_SEEDS ?= 1 7 42 123 2026
COV        ?= 1
ifeq ($(COV),1)
COV_OPTS    = -coverage all -covoverwrite -covtest $(UVM_TEST)_s$(ARRAY_SIZE)_seed$(SEED)
else
COV_OPTS    =
endif
FW_HEX      = ../sw/firmware/firmware.hex

.PHONY: uvm uvm-waves uvm-err uvm-regress

fw-imem: $(FW_HEX)
	cp $(FW_HEX) imem.hex

uvm: fw-imem
	xrun -uvm -uvmhome CDNS-1.2 $(XRUN_OPTS) -nowarn CUVIHR \
	  $(COV_OPTS) \
	  -svseed $(SEED) +define+ARRAY_SIZE=$(ARRAY_SIZE) \
	  -f filelists/uvm.f -top top_tb +UVM_TESTNAME=$(UVM_TEST) \
	  -l uvm_$(UVM_TEST)_s$(ARRAY_SIZE)_seed$(SEED).log
	@echo "=== Resultado ==="
	@grep -E "coverage \[COV\]|TEST (PASS|FAIL)|UVM_(ERROR|FATAL)=" uvm_$(UVM_TEST)_s$(ARRAY_SIZE)_seed$(SEED).log

uvm-waves: fw-imem
	xrun -uvm -uvmhome CDNS-1.2 $(XRUN_OPTS) -nowarn CUVIHR \
	  -svseed $(SEED) +define+ARRAY_SIZE=$(ARRAY_SIZE) \
	  -f filelists/uvm.f -top top_tb +UVM_TESTNAME=$(UVM_TEST) \
	  -input probe.tcl -l uvm_waves.log
	simvision waves.shm &

uvm-err: fw-imem
	xrun -uvm -uvmhome CDNS-1.2 $(XRUN_OPTS) -nowarn CUVIHR \
	  -svseed $(SEED) +define+ARRAY_SIZE=$(ARRAY_SIZE) \
	  -f filelists/uvm.f -top top_tb +UVM_TESTNAME=soc_directed_test \
	  +define+INJECT_BUG -l uvm_err.log

uvm-regress:
	for s in 2 4 8; do \
	  $(MAKE) uvm ARRAY_SIZE=$$s UVM_TEST=soc_directed_test SEED=1; \
	done
	for s in 2 4 8; do for seed in $(REGRESS_SEEDS); do \
	  $(MAKE) uvm ARRAY_SIZE=$$s UVM_TEST=soc_random_test SEED=$$seed; \
	done; done
	@echo "=== Resumo da regressao ===" | tee regress_summary.log
	@grep -H -E "TEST (PASS|FAIL)|Cobertura funcional" uvm_soc_*_seed*.log | tee -a regress_summary.log
