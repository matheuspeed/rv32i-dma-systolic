// tb_accel_top: teste rápido do wrapper do acelerador (buffers + controle + mux de saída)
//  1. K numa passagem (acc_clear = 1, klen = K)
//  2. K em duas passagens (clear só na primeira, klen = K/2 em cada)
// Em cada teste: carrega os buffers pela interface buf_*, dispara com acc_start,
// espera acc_done, confere a latência e lê os S² acumuladores pelo c_sel.
module tb_accel_top;

    parameter ARRAY_SIZE = 4;
    parameter DATA_W     = 8;
    parameter ACC_W      = 32;
    parameter BUF_DEPTH  = 16;
    parameter K          = 8;
    parameter VEC_DIR    = "vec_4x4";

    reg  clk, rst;
    reg  buf_we, buf_sel;
    reg  [$clog2(ARRAY_SIZE)-1:0]            buf_bank;
    reg  [$clog2(BUF_DEPTH)-1:0]             buf_addr;
    reg  [DATA_W-1:0]                        buf_wdata;
    reg  acc_start, acc_clear;
    reg  [$clog2(BUF_DEPTH):0]               acc_klen;
    wire acc_busy, acc_done;
    reg  [$clog2(ARRAY_SIZE*ARRAY_SIZE)-1:0] c_sel;
    wire [ACC_W-1:0]                         c_data;

    reg [DATA_W-1:0] A [0:ARRAY_SIZE*K-1];
    reg [DATA_W-1:0] B [0:K*ARRAY_SIZE-1];
    reg [ACC_W-1:0]  C [0:ARRAY_SIZE*ARRAY_SIZE-1];

    integer erros, erros_total, ciclos, p, i, k;

    accel_top #(
        .ARRAY_SIZE(ARRAY_SIZE), .DATA_W(DATA_W), .ACC_W(ACC_W), .BUF_DEPTH(BUF_DEPTH)
    ) dut (
        .clk(clk), .rst(rst),
        .buf_we(buf_we), .buf_sel(buf_sel), .buf_bank(buf_bank),
        .buf_addr(buf_addr), .buf_wdata(buf_wdata),
        .acc_start(acc_start), .acc_clear(acc_clear), .acc_klen(acc_klen),
        .acc_busy(acc_busy), .acc_done(acc_done),
        .c_sel(c_sel), .c_data(c_data)
    );

    initial begin
        clk = 0;
        forever #5 clk = !clk;
    end

    // carrega no buffer A as linhas de A e no buffer B as colunas de B,
    // elementos k0 .. k0+klen-1, a partir da posição 0 de cada banco
    task load_chunk(input integer k0, input integer klen);
        begin
            for (i = 0; i < ARRAY_SIZE; i = i + 1)
                for (p = 0; p < klen; p = p + 1) begin
                    buf_we = 1; buf_sel = 0; buf_bank = i; buf_addr = p;
                    buf_wdata = A[i*K + k0 + p];
                    @(negedge clk);
                end
            for (i = 0; i < ARRAY_SIZE; i = i + 1)
                for (p = 0; p < klen; p = p + 1) begin
                    buf_we = 1; buf_sel = 1; buf_bank = i; buf_addr = p;
                    buf_wdata = B[(k0 + p)*ARRAY_SIZE + i];
                    @(negedge clk);
                end
            buf_we = 0;
        end
    endtask

    // dispara uma passagem e espera o acc_done; confere a latência
    task run_pass(input clr, input integer klen);
        begin
            acc_start = 1; acc_clear = clr; acc_klen = klen;
            @(negedge clk);
            acc_start = 0; acc_clear = 0;
            ciclos = 0;
            while (acc_done !== 1'b1) begin
                if (acc_busy !== 1'b1 && acc_done !== 1'b1) begin
                    $display("[FAIL] acc_busy caiu antes do acc_done");
                    erros = erros + 1;
                end
                @(negedge clk);
                ciclos = ciclos + 1;
                if (ciclos > 200) begin
                    $display("[FAIL] acc_done nunca chegou");
                    erros = erros + 1;
                    disable run_pass;
                end
            end
            // CLEAR (1) + passagem (klen + 2(S-1)) ciclos até o acc_done aparecer
            if (ciclos !== 1 + klen + 2*(ARRAY_SIZE-1)) begin
                $display("[FAIL] latencia: %0d ciclos, esperado %0d", ciclos, 1 + klen + 2*(ARRAY_SIZE-1));
                erros = erros + 1;
            end else
                $display("[PASS] latencia: %0d ciclos", ciclos);
            @(negedge clk);
            if (acc_done !== 1'b0 || acc_busy !== 1'b0) begin
                $display("[FAIL] acc_done deveria durar 1 ciclo e acc_busy cair");
                erros = erros + 1;
            end
        end
    endtask

    // lê os S² acumuladores pelo c_sel e compara com C
    task check_c;
        begin
            for (k = 0; k < ARRAY_SIZE*ARRAY_SIZE; k = k + 1) begin
                c_sel = k;
                #1;
                if (c_data !== C[k]) erros = erros + 1;
                $display("[%s] C[%0d][%0d] obtido 0x%0h esperado 0x%0h",
                         (c_data !== C[k]) ? "FAIL" : "PASS",
                         k/ARRAY_SIZE, k%ARRAY_SIZE, c_data, C[k]);
            end
        end
    endtask

    initial begin
        $readmemh({VEC_DIR, "/A.hex"}, A);
        $readmemh({VEC_DIR, "/B.hex"}, B);
        $readmemh({VEC_DIR, "/C_expected.hex"}, C);
        rst = 1; buf_we = 0; buf_sel = 0; buf_bank = 0; buf_addr = 0; buf_wdata = 0;
        acc_start = 0; acc_clear = 0; acc_klen = 0; c_sel = 0;
        erros_total = 0;
        @(negedge clk);
        rst = 0;
        @(negedge clk);

        $display("--- Teste 1: K numa passagem ---");
        erros = 0;
        load_chunk(0, K);
        run_pass(1, K);
        check_c;
        erros_total = erros_total + erros;

        $display("--- Teste 2: K em duas passagens ---");
        erros = 0;
        load_chunk(0, K/2);
        run_pass(1, K/2);
        load_chunk(K/2, K - K/2);
        run_pass(0, K - K/2);
        check_c;
        erros_total = erros_total + erros;

        if (erros_total == 0) $display(">>> TESTE PASSOU <<<");
        else                  $display(">>> TESTE FALHOU: %0d erro(s) <<<", erros_total);
        $finish;
    end

endmodule
