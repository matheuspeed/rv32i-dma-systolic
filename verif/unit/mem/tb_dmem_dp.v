// tb_dmem_dp: teste rápido da memória dual-port
//  1. escrita pela porta B, leitura pela porta A (LW, LB, LBU)
//  2. escrita pela porta A (SW, SB), leitura pela porta B
//  3. latência de 1 ciclo da leitura da porta B
module tb_dmem_dp;

    reg         clk;
    reg  [31:0] a, wd;
    reg         we;
    reg  [2:0]  mode;
    wire [31:0] rd;
    reg  [9:0]  memb_addr;
    reg  [31:0] memb_wdata;
    reg         memb_we;
    wire [31:0] memb_rdata;

    integer erros;

    dmem_dp dut (
        .clk(clk), .a(a), .wd(wd), .we(we), .mode(mode), .rd(rd),
        .memb_addr(memb_addr), .memb_wdata(memb_wdata),
        .memb_we(memb_we), .memb_rdata(memb_rdata)
    );

    initial begin
        clk = 0;
        forever #5 clk = !clk;
    end

    task confere(input [31:0] obtido, input [31:0] esperado, input [8*32-1:0] nome);
        begin
            if (obtido !== esperado) erros = erros + 1;
            $display("[%s] %0s: obtido 0x%08h, esperado 0x%08h",
                     (obtido !== esperado) ? "FAIL" : "PASS", nome, obtido, esperado);
        end
    endtask

    initial begin
        erros = 0;
        a = 0; wd = 0; we = 0; mode = 3'b000;
        memb_addr = 0; memb_wdata = 0; memb_we = 0;

        // 1. porta B escreve a palavra 768 (byte 0xC00), porta A lê
        @(negedge clk);
        memb_addr = 10'd768; memb_wdata = 32'hA1B2C3F4; memb_we = 1;
        @(negedge clk);
        memb_we = 0;
        a = 32'h0000_0C00;
        mode = 3'b000; #1 confere(rd, 32'hA1B2C3F4, "B escreve, A le (LW)");
        mode = 3'b100; #1 confere(rd, 32'hFFFFFFF4, "B escreve, A le (LB)");
        mode = 3'b011; #1 confere(rd, 32'h000000F4, "B escreve, A le (LBU)");
        a = 32'h0000_0C03;
        mode = 3'b011; #1 confere(rd, 32'h000000A1, "byte 3 (little-endian)");

        // 2. porta A escreve SW em 0x400 e SB em 0x401, porta B lê a palavra 256
        @(negedge clk);
        a = 32'h0000_0400; wd = 32'h11223344; mode = 3'b000; we = 1;
        @(negedge clk);
        a = 32'h0000_0401; wd = 32'h000000EE; mode = 3'b011;
        @(negedge clk);
        we = 0;
        memb_addr = 10'd256;
        // 3. latência: o dado só aparece depois da próxima borda de subida
        @(posedge clk); #1;
        confere(memb_rdata, 32'h1122EE44, "A escreve, B le");
        memb_addr = 10'd768;
        #1 confere(memb_rdata, 32'h1122EE44, "antes da borda: dado antigo");
        @(posedge clk); #1;
        confere(memb_rdata, 32'hA1B2C3F4, "depois da borda: dado novo");

        // 4. endereço acima de 4 KB usa só os 12 bits baixos (0x10C00 -> 0xC00)
        a = 32'h0001_0C00; mode = 3'b000;
        #1 confere(rd, 32'hA1B2C3F4, "a[11:0] (0x10C00)");

        if (erros == 0) $display(">>> TESTE PASSOU <<<");
        else            $display(">>> TESTE FALHOU: %0d erro(s) <<<", erros);
        $finish;
    end

endmodule
