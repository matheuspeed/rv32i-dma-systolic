
module tb_dma;

  // Parameters
    parameter ARRAY_SIZE = 2;
    parameter DATA_W     = 8;
    parameter ACC_W      = 32;
    parameter BUF_DEPTH  = 16;
    parameter M = 2, N = 2, K = 8;
    parameter VEC_DIR    = "vec_dma_basic";

    localparam ADDR_A = 32'h400, ADDR_B = 32'h800, ADDR_C = 32'hC00;

    //Ports
    reg clk;
    reg rst;
    wire  irq;
    reg [7:0] reg_addr;
    reg [31:0] reg_wdata;
    reg reg_we;
    wire [31:0] reg_rdata;
    wire [31:0] memb_rdata;
    wire [9:0] memb_addr;
    wire [31:0] memb_wdata;
    wire memb_we;
    wire [$clog2(ARRAY_SIZE)-1:0] buf_bank;
    wire buf_we;
    wire buf_sel;
    wire [$clog2(BUF_DEPTH)-1:0] buf_addr;
    wire [DATA_W-1:0] buf_wdata;
    wire acc_busy;
    wire acc_done;
    wire [ACC_W-1:0] c_data;
    wire acc_start;
    wire acc_clear;
    wire [$clog2(BUF_DEPTH):0] acc_klen;
    wire [$clog2(ARRAY_SIZE*ARRAY_SIZE)-1:0] c_sel;

    reg [31:0] a_cpu, wd_cpu;
    reg        we_cpu;
    reg [2:0]  mode_cpu;

    reg [31:0] init     [0:1023];   // dmem_init.hex
    reg [31:0] expected [0:1023];   // dmem_expected.hex

    reg [31:0] lido, palavra;

    dma # (
        .ARRAY_SIZE(ARRAY_SIZE),
        .BUF_DEPTH(BUF_DEPTH),
        .ACC_W(ACC_W),
        .DATA_W(DATA_W)
    )
    dma_inst (
        .clk(clk),
        .rst(rst),
        .irq(irq),
        .reg_addr(reg_addr),
        .reg_wdata(reg_wdata),
        .reg_we(reg_we),
        .reg_rdata(reg_rdata),
        .memb_rdata(memb_rdata),
        .memb_addr(memb_addr),
        .memb_wdata(memb_wdata),
        .memb_we(memb_we),
        .buf_bank(buf_bank),
        .buf_we(buf_we),
        .buf_sel(buf_sel),
        .buf_addr(buf_addr),
        .buf_wdata(buf_wdata),
        .acc_busy(acc_busy),
        .acc_done(acc_done),
        .c_data(c_data),
        .acc_start(acc_start),
        .acc_clear(acc_clear),
        .acc_klen(acc_klen),
        .c_sel(c_sel)
    );

    dmem_dp  dmem_dp_inst (
        .clk(clk),
        .a(a_cpu),
        .wd(wd_cpu),
        .we(we_cpu),
        .mode(mode_cpu),
        .rd(),
        .memb_addr(memb_addr),
        .memb_wdata(memb_wdata),
        .memb_we(memb_we),
        .memb_rdata(memb_rdata)
    );

    accel_top # (
        .ARRAY_SIZE(ARRAY_SIZE),
        .DATA_W(DATA_W),
        .ACC_W(ACC_W),
        .BUF_DEPTH(BUF_DEPTH)
    )
    accel_top_inst (
        .clk(clk),
        .rst(rst),
        .buf_we(buf_we),
        .buf_sel(buf_sel),
        .buf_bank(buf_bank),
        .buf_addr(buf_addr),
        .buf_wdata(buf_wdata),
        .acc_start(acc_start),
        .acc_clear(acc_clear),
        .acc_klen(acc_klen),
        .acc_busy(acc_busy),
        .acc_done(acc_done),
        .c_sel(c_sel),
        .c_data(c_data)
    );

    task reg_write(input [7:0] offset, input [31:0] valor);
        begin
            reg_addr  = offset;
            reg_wdata = valor;
            reg_we    = 1;
            @(negedge clk);
            reg_we    = 0;
        end
    endtask

    task reg_read(input [7:0] offset, output [31:0] valor);
        begin
            reg_addr = offset;
            #1;
            valor = reg_rdata;
        end
    endtask


    initial begin
        clk = 0;
        forever #5 clk = !clk;
    end

    integer w;
    integer erros, ciclos;
    initial begin
        rst = 1;
        reg_addr = 0;  reg_wdata = 0;  reg_we = 0;
        a_cpu = 0;  wd_cpu = 0;  we_cpu = 0;  mode_cpu = 0;
        erros = 0;

        $readmemh({VEC_DIR, "/dmem_init.hex"},     init);
        $readmemh({VEC_DIR, "/dmem_expected.hex"}, expected);
        for (w = 0; w < 1024; w = w + 1)
            {dmem_dp_inst.mem[4*w+3], dmem_dp_inst.mem[4*w+2],
                dmem_dp_inst.mem[4*w+1], dmem_dp_inst.mem[4*w]} = init[w];

        @(negedge clk);
        rst = 0;

        reg_write(8'h08, ADDR_A);
        reg_write(8'h0C, ADDR_B);
        reg_write(8'h10, ADDR_C);
        reg_write(8'h14, M);
        reg_write(8'h18, N);
        reg_write(8'h1C, K);
        reg_write(8'h00, 32'h3);     // bit 0 = START, bit 1 = IRQ_EN

        ciclos = 0;
        while (irq !== 1'b1 && ciclos < 20000) begin
            @(negedge clk);
            ciclos = ciclos + 1;
        end
        if (irq !== 1'b1) begin
            $display("[FAIL] irq nao subiu em %0d ciclos (estado do DMA = %0d)", ciclos, dma_inst.state);
            erros = erros + 1;
        end

        reg_read(8'h04, lido);      // STATUS
        if (lido !== 32'h2) begin
            $display("[FAIL] STATUS = 0x%0h, esperado 0x2 (DONE=1, BUSY=0)", lido);
            erros = erros + 1;
        end else
            $display("[PASS] STATUS: DONE=1, BUSY=0");
        reg_read(8'h20, lido);      // CYCLES
        $display("CYCLES = %0d", lido);

        for (w = 0; w < 1024; w = w + 1) begin
            palavra = {dmem_dp_inst.mem[4*w+3], dmem_dp_inst.mem[4*w+2],
                    dmem_dp_inst.mem[4*w+1], dmem_dp_inst.mem[4*w]};
            if (palavra !== expected[w]) begin
                erros = erros + 1;
                $display("[FAIL] MEM[0x%03h] obtido 0x%08h esperado 0x%08h", 4*w, palavra, expected[w]);
            end
        end

        reg_write(8'h04, 32'h2);     // escreve 1 no bit 1 do STATUS
        reg_read(8'h04, lido);
        if (lido !== 32'h0 || irq !== 1'b0) begin
            $display("[FAIL] W1C: STATUS = 0x%0h, irq = %b (esperado 0 e 0)", lido, irq);
            erros = erros + 1;
        end else
            $display("[PASS] W1C: DONE e irq limpos");
        if (erros == 0)
            $display("[PASS] memoria: 1024 palavras conferem (C com %0d elementos em 0x%03h)", M*N, ADDR_C);

        if (erros == 0) $display(">>> TESTE PASSOU <<<");
        else                  $display(">>> TESTE FALHOU: %0d erro(s) <<<", erros);
        $finish;
    end
endmodule