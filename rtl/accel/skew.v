// skew: atraso escalonado das entradas da malha sistólica.
// A posição i de din sai em dout com i ciclos de atraso
// (posição 0 passa direto). Usado para A (linhas) e para B (colunas).
module skew #(
    parameter N = 4,            // número de posições (= ARRAY_SIZE)
    parameter DATA_W = 8        // largura de cada valor (int8)
)(
    input clk, rst,
    input [N*DATA_W-1:0] din,   // N valores alinhados; posição i em [i*DATA_W +: DATA_W]
    output [N*DATA_W-1:0] dout  // mesmos valores, posição i atrasada i ciclos
);

genvar i;
generate
    for (i = 0; i < N; i = i + 1) begin : g_pos        // uma iteração por posição
        if (i == 0) begin : g_direct                    // posição 0: sem atraso, fio direto
            assign dout[0 +: DATA_W] = din[0 +: DATA_W];
        end else begin : g_chain                        // posição i: cadeia de i registradores
                reg [DATA_W-1:0] r [0:i-1];             // r[0] = 1º estágio ... r[i-1] = último
                integer k;
                always@(posedge clk or posedge rst) begin
                    if (rst)
                        for (k = 0; k < i; k = k + 1) begin
                            r[k] <= {DATA_W{1'b0}};
                        end
                    else begin
                        r[0] <= din[i*DATA_W +: DATA_W]; // 1º estágio recebe a entrada
                        for (k = 1; k < i; k = k + 1) begin
                            r[k] <= r[k-1];             // demais avançam um estágio
                        end
                    end
                end
                assign dout[i*DATA_W +: DATA_W] = r[i-1]; // saída = último estágio
        end
    end

endgenerate

endmodule