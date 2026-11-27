interface soc_if (input logic clk);
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    logic        rst;
    logic        irq;
    logic [31:0] dbus_addr;
    logic [31:0] dbus_wdata;
    logic        dbus_we;
    logic [31:0] dbus_rdata;
    logic        acc_start;
    logic        acc_busy;
    logic        acc_done;

    // Backdoor na DMEM (mem[0:4095] de 8 bits little-endian, igual ao tb_dma.v)
    task automatic write_dmem_byte(input logic [11:0] addr, input logic [7:0] data);
        top_tb.dut.u_dmem.mem[addr] = data;
    endtask

    function automatic logic [7:0] read_dmem_byte(input logic [11:0] addr);
        return top_tb.dut.u_dmem.mem[addr];
    endfunction

    task automatic write_dmem_word(input logic [11:0] addr, input logic [31:0] data);
        top_tb.dut.u_dmem.mem[addr + 0] = data[7:0];
        top_tb.dut.u_dmem.mem[addr + 1] = data[15:8];
        top_tb.dut.u_dmem.mem[addr + 2] = data[23:16];
        top_tb.dut.u_dmem.mem[addr + 3] = data[31:24];
    endtask

    function automatic logic [31:0] read_dmem_word(input logic [11:0] addr);
        return {top_tb.dut.u_dmem.mem[addr + 3],
                top_tb.dut.u_dmem.mem[addr + 2],
                top_tb.dut.u_dmem.mem[addr + 1],
                top_tb.dut.u_dmem.mem[addr + 0]};
    endfunction

    // Região de C programada pelo firmware, capturada no barramento da CPU
    // (offsets do DMA: 0x10 ADDR_C, 0x14 DIM_M, 0x18 DIM_N)
    logic [31:0] c_base, c_dim_m, c_dim_n;
    initial begin
        c_base  = '0;
        c_dim_m = '0;
        c_dim_n = '0;
    end
    always @(posedge clk) begin
        if (dbus_we && dbus_addr[16]) begin
            case (dbus_addr[7:0])
                8'h10: c_base  <= dbus_wdata;
                8'h14: c_dim_m <= dbus_wdata;
                8'h18: c_dim_n <= dbus_wdata;
                default: ;
            endcase
        end
    end
    // C ocupa M x N elementos de 4 bytes (int32) a partir de ADDR_C
    wire [31:0] c_end        = c_base + c_dim_m * c_dim_n * 4;
    wire        cpu_writes_c = dbus_we && !dbus_addr[16] &&
                               (dbus_addr >= c_base) && (dbus_addr < c_end);

    // Assertions (SVA - Seção 7.3 do Plano + Bônus de Autonomia do DMA).
    // Falhas viram `uvm_error: entram na contagem de UVM_ERROR e no veredito.
    property p_acc_handshake;
        @(posedge clk) disable iff (rst)
        acc_start |=> acc_busy;
    endproperty
    AST_01_HANDSHAKE: assert property (p_acc_handshake)
        else `uvm_error("SVA", "AST-01 falhou: acc_busy nao subiu apos acc_start")

    property p_acc_done_pulse;
        @(posedge clk) disable iff (rst)
        acc_done |=> !acc_done;
    endproperty
    AST_02_DONE_PULSE: assert property (p_acc_done_pulse)
        else `uvm_error("SVA", "AST-02 falhou: acc_done permaneceu alto por mais de 1 ciclo")

    property p_cpu_no_write_c;
        @(posedge clk) disable iff (rst)
        cpu_writes_c |-> !acc_busy;
    endproperty
    AST_03_DMA_AUTONOMY: assert property (p_cpu_no_write_c)
        else `uvm_error("SVA", $sformatf("AST-03 falhou: CPU escreveu em 0x%03h (regiao de C) com o acelerador ocupado", dbus_addr))

endinterface