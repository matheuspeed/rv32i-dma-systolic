module mac #(
    parameter DATA_W = 8,
    parameter ACC_W = 32
)(
    input clk, rst, clear,
    input signed [DATA_W-1:0] a_in, b_in,
    output reg signed [DATA_W-1:0] a_out, b_out,
    output reg signed [ACC_W-1:0] acc
);


    always@(posedge clk or posedge rst) begin
        if (rst) begin
            a_out <= {DATA_W{1'b0}};
            b_out <= {DATA_W{1'b0}};
            acc <= {ACC_W{1'b0}};
        end else begin
            a_out <= a_in;
            b_out <= b_in;
            if (clear)
                acc <= {ACC_W{1'b0}};
            else
                acc <= acc + a_in * b_in;
        end
    end

endmodule