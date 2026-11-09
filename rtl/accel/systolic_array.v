module systolic_array #(
    parameter ARRAY_SIZE = 4,
    parameter DATA_W = 8,
    parameter ACC_W = 32
) (
    input clk, rst, clear,
    input [ARRAY_SIZE*DATA_W-1:0] a_col, b_row,
    output [ARRAY_SIZE*ARRAY_SIZE*ACC_W-1:0] acc_flat
);

    wire [DATA_W-1:0] a_h [0:ARRAY_SIZE-1][0:ARRAY_SIZE];
    wire [DATA_W-1:0] b_v [0:ARRAY_SIZE][0:ARRAY_SIZE-1];
    wire [ARRAY_SIZE*DATA_W-1:0] a_skew, b_skew;

    skew #(.N(ARRAY_SIZE), .DATA_W(DATA_W))
        u_skew_a
        (.din(a_col), .dout(a_skew),
        .clk(clk), .rst(rst));

    skew #(.N(ARRAY_SIZE), .DATA_W(DATA_W))
        u_skew_b
        (.din(b_row), .dout(b_skew),
        .clk(clk), .rst(rst));

    genvar i;
    generate
        for (i = 0; i < ARRAY_SIZE; i = i + 1) begin: g_edge
            assign a_h[i][0] = a_skew[i*DATA_W +: DATA_W];
            assign b_v[0][i] = b_skew[i*DATA_W +: DATA_W];
        end
    endgenerate

    genvar j;
    generate
        for(i = 0; i < ARRAY_SIZE; i = i + 1) begin: g_row
            for(j = 0; j < ARRAY_SIZE; j = j + 1) begin: g_col
                mac #(.DATA_W(DATA_W), .ACC_W(ACC_W)) 
                    u_mac
                    (.clk(clk), .rst(rst), .clear(clear),
                    .a_in(a_h[i][j]), .b_in(b_v[i][j]),
                    .a_out(a_h[i][j+1]), .b_out(b_v[i+1][j]),
                    .acc(acc_flat[(i*ARRAY_SIZE+j)*ACC_W +: ACC_W]));
            end
        end
    endgenerate

endmodule