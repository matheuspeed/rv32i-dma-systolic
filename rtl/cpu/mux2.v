module mux2 (
    input wire s,
    input wire [31:0] a,
    input wire [31:0] b,
    output wire [31:0] o
);
    assign o = (s) ? a : b;
endmodule