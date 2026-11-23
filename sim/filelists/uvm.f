// RTL do SoC
../rtl/cpu/adder.v
../rtl/cpu/alu.v
../rtl/cpu/control.v
../rtl/cpu/extend_imm.v
../rtl/cpu/mux2.v
../rtl/cpu/mux4.v
../rtl/cpu/pc.v
../rtl/cpu/regfile.v
../rtl/cpu/riscv_top.v
../rtl/mem/imem.v
../rtl/mem/dmem_dp.v
../rtl/accel/mac.v
../rtl/accel/skew.v
../rtl/accel/systolic_array.v
../rtl/accel/accel_top.v
../rtl/dma/dma.v
../rtl/top/soc_top.v

// Ambiente UVM
+incdir+../verif/uvm/agents/soc_agent
+incdir+../verif/uvm/env
+incdir+../verif/uvm/tests
../verif/uvm/agents/soc_agent/soc_if.sv
../verif/uvm/agents/soc_agent/soc_agent_pkg.sv
../verif/uvm/env/soc_env_pkg.sv
../verif/uvm/tests/soc_tests_pkg.sv
../verif/uvm/top/top_tb.sv