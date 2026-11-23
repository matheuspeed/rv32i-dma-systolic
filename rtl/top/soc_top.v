// rtl/top/soc_top.v
module soc_top #(
    parameter ARRAY_SIZE = 4,
    parameter DATA_W     = 8,
    parameter ACC_W      = 32,
    parameter BUF_DEPTH  = 16
)(
    input  wire        clk,
    input  wire        rst,
    output wire        irq,
    output wire [31:0] pc_out,
    output wire [31:0] instr_out,
    output wire [31:0] alu_result_out,
    output wire [31:0] reg_write_data_out,
    output wire [31:0] mem_write_data_out
);

    // Barramento de dados da CPU
    wire [31:0] dbus_addr;
    wire [31:0] dbus_wdata;
    wire        dbus_we;
    wire [2:0]  dbus_mode;
    wire [31:0] dmem_rdata;
    wire [31:0] dma_rdata;
    wire [31:0] dbus_rdata;

    // Decodificação: addr[16] == 0 -> DMEM, addr[16] == 1 -> MMIO DMA
    wire sel_dma = dbus_addr[16];
    wire dmem_we = dbus_we & ~sel_dma;
    wire dma_we  = dbus_we &  sel_dma;

    assign dbus_rdata = sel_dma ? dma_rdata : dmem_rdata;

    // Porta B da DMEM (DMA)
    wire [9:0]  memb_addr;
    wire [31:0] memb_wdata;
    wire        memb_we;
    wire [31:0] memb_rdata;

    // Interconexão DMA <-> Acelerador
    wire [$clog2(ARRAY_SIZE)-1:0]            buf_bank;
    wire                                     buf_we;
    wire                                     buf_sel;
    wire [$clog2(BUF_DEPTH)-1:0]             buf_addr;
    wire [DATA_W-1:0]                        buf_wdata;
    wire                                     acc_busy;
    wire                                     acc_done;
    wire [ACC_W-1:0]                         c_data;
    wire                                     acc_start;
    wire                                     acc_clear;
    wire [$clog2(BUF_DEPTH):0]               acc_klen;
    wire [$clog2(ARRAY_SIZE*ARRAY_SIZE)-1:0] c_sel;

    riscv_top u_cpu (
        .clk                (clk),
        .rst                (rst),
        .dbus_addr          (dbus_addr),
        .dbus_wdata         (dbus_wdata),
        .dbus_we            (dbus_we),
        .dbus_mode          (dbus_mode),
        .dbus_rdata         (dbus_rdata),
        .pc_out             (pc_out),
        .instr_out          (instr_out),
        .alu_result_out     (alu_result_out),
        .reg_write_data_out (reg_write_data_out),
        .mem_write_data_out (mem_write_data_out)
    );

    dmem_dp u_dmem (
        .clk        (clk),
        .a          (dbus_addr),
        .wd         (dbus_wdata),
        .we         (dmem_we),
        .mode       (dbus_mode),
        .rd         (dmem_rdata),
        .memb_addr  (memb_addr),
        .memb_wdata (memb_wdata),
        .memb_we    (memb_we),
        .memb_rdata (memb_rdata)
    );

    dma #(
        .ARRAY_SIZE (ARRAY_SIZE),
        .BUF_DEPTH  (BUF_DEPTH),
        .ACC_W      (ACC_W),
        .DATA_W     (DATA_W)
    ) u_dma (
        .clk        (clk),
        .rst        (rst),
        .irq        (irq),
        .reg_addr   (dbus_addr[7:0]),
        .reg_wdata  (dbus_wdata),
        .reg_we     (dma_we),
        .reg_rdata  (dma_rdata),
        .memb_rdata (memb_rdata),
        .memb_addr  (memb_addr),
        .memb_wdata (memb_wdata),
        .memb_we    (memb_we),
        .buf_bank   (buf_bank),
        .buf_we     (buf_we),
        .buf_sel    (buf_sel),
        .buf_addr   (buf_addr),
        .buf_wdata  (buf_wdata),
        .acc_busy   (acc_busy),
        .acc_done   (acc_done),
        .c_data     (c_data),
        .acc_start  (acc_start),
        .acc_clear  (acc_clear),
        .acc_klen   (acc_klen),
        .c_sel      (c_sel)
    );

    accel_top #(
        .ARRAY_SIZE (ARRAY_SIZE),
        .DATA_W     (DATA_W),
        .ACC_W      (ACC_W),
        .BUF_DEPTH  (BUF_DEPTH)
    ) u_accel (
        .clk       (clk),
        .rst       (rst),
        .buf_we    (buf_we),
        .buf_sel   (buf_sel),
        .buf_bank  (buf_bank),
        .buf_addr  (buf_addr),
        .buf_wdata (buf_wdata),
        .acc_start (acc_start),
        .acc_clear (acc_clear),
        .acc_klen  (acc_klen),
        .acc_busy  (acc_busy),
        .acc_done  (acc_done),
        .c_sel     (c_sel),
        .c_data    (c_data)
    );

endmodule