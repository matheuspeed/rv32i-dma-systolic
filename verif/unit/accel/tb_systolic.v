
module tb_systolic;

  // Parameters
    parameter ARRAY_SIZE = 4;
    parameter DATA_W     = 8;
    parameter ACC_W      = 32;
    parameter K          = 8;
    parameter VEC_DIR    = "vec_4x4";

    //Ports
    reg clk, rst, clear;
    reg [ARRAY_SIZE*DATA_W-1:0] a_col, b_row;
    wire [ARRAY_SIZE*ARRAY_SIZE*ACC_W-1:0] acc_flat;

    reg [DATA_W-1:0] A [0:ARRAY_SIZE*K-1];
    reg [DATA_W-1:0] B [0:K*ARRAY_SIZE-1];
    reg [ACC_W-1:0]  C [0:ARRAY_SIZE*ARRAY_SIZE-1];

    systolic_array # (
        .ARRAY_SIZE(ARRAY_SIZE),
        .DATA_W(DATA_W),
        .ACC_W(ACC_W))
    systolic_array_inst
    (
        .clk(clk),
        .rst(rst),
        .clear(clear),
        .a_col(a_col),
        .b_row(b_row),
        .acc_flat(acc_flat)
    );

    initial begin
        clk = 0;
        forever begin
            #5;
            clk = !clk;
        end
    end

    integer erros_total;
    integer erros, k;
    integer t, i;

    initial begin
        $readmemh({VEC_DIR, "/A.hex"}, A);
        $readmemh({VEC_DIR, "/B.hex"}, B);
        $readmemh({VEC_DIR, "/C_expected.hex"}, C);
        rst = 1;
        clear = 0;
        a_col = 0;
        b_row = 0;
        erros_total = 0;

        @(negedge clk);
        rst = 0;

        //Testa funcionamento dos módulos com um buffer inteiro em sequencia
        $display("Teste 1: K inteiro numa passagem");
        @(negedge clk);
        do_clear;
        feed(0, K);
        check;
        erros_total = erros_total + erros;

        //Testa funcionamento dos módulos com buffer particionado
        $display("Teste 2: K em duas passagens (acumulação)");
        do_clear;
        feed(0, K/2);
        feed(K/2, K/2);
        check;
        erros_total = erros_total + erros;

        $display("Teste 3: clear zera os acumuladores");
        do_clear;
        check_zero;
        erros_total = erros_total + erros;

        if (erros_total == 0)
            $display("Teste passou");
        else
            $display("Teste falhou: %0d erros", erros_total);

        $finish;
    end

    task do_clear;
        begin
            clear = 1;
            @(negedge clk);
            clear = 0;
        end
    endtask

    task feed(
        input integer k0, klen
    );
        begin
            for (t = 0; t < klen + 2*(ARRAY_SIZE-1); t = t + 1) begin
                for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
                    if (t < klen) begin
                        a_col[i*DATA_W +: DATA_W] = A[i*K + (k0+t)] ;
                        b_row[i*DATA_W +: DATA_W] = B[(k0+t)*ARRAY_SIZE + i];
                    end else begin
                        a_col[i*DATA_W +: DATA_W] = 0;
                        b_row[i*DATA_W +: DATA_W] = 0;
                    end
                end
                @(negedge clk);
            end
        end
    endtask

    task check;
        begin
            erros = 0;
            for (k = 0; k < ARRAY_SIZE*ARRAY_SIZE; k = k + 1) begin
                if (acc_flat[k*ACC_W +: ACC_W] !== C[k])
                    erros = erros + 1;
                $display("[%s] C[%0d][%0d] Obtido: 0x%0h Esperado: 0x%0h", (acc_flat[k*ACC_W +: ACC_W] !== C[k]) ? "FAIL" : "PASS",
                            k/ARRAY_SIZE, k%ARRAY_SIZE, acc_flat[k*ACC_W +: ACC_W], C[k]);
            end
            $display("[%s]", (erros == 0) ? "PASSOU" : "FALHOU");
            $display("Erros obtidos: %0d", erros);
        end
    endtask

    task check_zero;
        begin
            erros = 0;
            for (k = 0; k < ARRAY_SIZE*ARRAY_SIZE; k = k + 1) begin
                if (acc_flat[k*ACC_W +: ACC_W] !== 0)
                    erros = erros + 1;
                $display("[%s] C[%0d][%0d] Obtido: 0x%0h", (acc_flat[k*ACC_W +: ACC_W] !== 0) ? "FAIL" : "PASS",
                            k/ARRAY_SIZE, k%ARRAY_SIZE, acc_flat[k*ACC_W +: ACC_W]);
            end
            $display("[%s]", (erros == 0) ? "PASSOU" : "FALHOU");
            $display("Erros obtidos: %0d", erros);
        end
    endtask

endmodule