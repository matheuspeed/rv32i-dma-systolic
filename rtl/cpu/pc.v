module pc (
    input wire clk,
    input wire rst,
    input wire [31:0] a,
    output reg [31:0] o
);
    always @(posedge clk or posedge rst) begin
        if (rst)
            o <= 32'd0;
        else
            o <= a;
    end
endmodule