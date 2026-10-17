module regfile (
    input wire clk,
    input wire rst,
    input wire we,
    input wire [4:0] rs1,
    input wire [4:0] rs2,
    input wire [4:0] rd,
    input wire [31:0] wr_rd,
    output wire [31:0] rs1_o,
    output wire [31:0] rs2_o
);
    reg [31:0] mem [0:31];
    integer i;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1)
                mem[i] <= 32'b0;
        end else if (we && (rd != 5'b0)) begin
            mem[rd] <= wr_rd;
        end
    end

    // x0 é mantido fixo em zero na leitura
    assign rs1_o = (rs1 == 5'b0) ? 32'b0 : mem[rs1];
    assign rs2_o = (rs2 == 5'b0) ? 32'b0 : mem[rs2];
endmodule