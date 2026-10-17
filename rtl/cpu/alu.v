module ALU (
    input wire [31:0] a,
    input wire [31:0] b,
    input wire [3:0] ALUControl,
    output reg [31:0] result
);
    localparam ADD  = 4'b0000;
    localparam SUB  = 4'b0001;
    localparam AND  = 4'b0010;
    localparam OR   = 4'b0011;
    localparam XOR  = 4'b0100;
    localparam SLL  = 4'b0101;
    localparam SRL  = 4'b0110;
    localparam SRA  = 4'b0111;
    localparam EQ   = 4'b1000;
    localparam ULT  = 4'b1001;
    localparam UGTE = 4'b1010;
    localparam SLT  = 4'b1011;
    localparam SGTE = 4'b1100;

    always @(*) begin
        case (ALUControl)
            ADD:  result = a + b;
            SUB:  result = a - b;
            AND:  result = a & b;
            OR:   result = a | b;
            XOR:  result = a ^ b;
            SLL:  result = a << b[4:0];
            SRL:  result = a >> b[4:0];
            SRA:  result = $signed(a) >>> b[4:0];
            EQ:   result = {31'b0, (a == b)};
            ULT:  result = {31'b0, (a < b)};
            UGTE: result = {31'b0, (a >= b)};
            SLT:  result = {31'b0, ($signed(a) < $signed(b))};
            SGTE: result = {31'b0, ($signed(a) >= $signed(b))};
            default: result = 32'b0;
        endcase
    end
endmodule