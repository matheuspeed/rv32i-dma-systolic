`timescale 1ns/1ps

module top_tb;
    import uvm_pkg::*;
    import soc_tests_pkg::*;
    `include "uvm_macros.svh"

    `ifndef ARRAY_SIZE
        `define ARRAY_SIZE 4
    `endif

    localparam int ARRAY_SIZE = `ARRAY_SIZE;

    logic clk;
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    soc_if vif (clk);

    wire [31:0] pc_out, instr_out, alu_result_out, reg_write_data_out, mem_write_data_out;

    soc_top #(
        .ARRAY_SIZE (ARRAY_SIZE),
        .BUF_DEPTH  (16)
    ) dut (
        .clk                (clk),
        .rst                (vif.rst),
        .irq                (vif.irq),
        .pc_out             (pc_out),
        .instr_out          (instr_out),
        .alu_result_out     (alu_result_out),
        .reg_write_data_out (reg_write_data_out),
        .mem_write_data_out (mem_write_data_out)
    );

    // Conexão passiva dos sinais internos para a interface
    assign vif.dbus_addr  = dut.dbus_addr;
    assign vif.dbus_wdata = dut.dbus_wdata;
    assign vif.dbus_we    = dut.dbus_we;
    assign vif.dbus_rdata = dut.dbus_rdata;
    assign vif.acc_start  = dut.acc_start;
    assign vif.acc_busy   = dut.acc_busy;
    assign vif.acc_done   = dut.acc_done;

    initial begin
        uvm_config_db#(virtual soc_if)::set(null, "uvm_test_top", "vif", vif);
        uvm_config_db#(int unsigned)::set(null, "uvm_test_top", "array_size", ARRAY_SIZE);
        run_test();
    end
endmodule