module dmem (
    input wire clk,
    input wire reset,
    input wire [31:0] a,
    output reg [31:0] rd,
    input wire [31:0] wd,
    input wire we,
    input wire [2:0] mode
);
    reg [7:0] mem [0:1023]; // Memória organizada em bytes

    // Leitura Assíncrona
    always @(*) begin
        case (mode)
            3'b000: // 4 bytes (LW)
                rd = {mem[a+3], mem[a+2], mem[a+1], mem[a]};
            3'b001: // Unsigned 2 bytes (LHU)
                rd = {16'b0, mem[a+1], mem[a]};
            3'b010: // Signed 2 bytes (LH)
                rd = {{16{mem[a+1][7]}}, mem[a+1], mem[a]};
            3'b011: // Unsigned 1 byte (LBU)
                rd = {24'b0, mem[a]};
            3'b100: // Signed 1 byte (LB)
                rd = {{24{mem[a][7]}}, mem[a]};
            default: rd = 32'b0;
        endcase
    end

    // Escrita Síncrona
    integer i;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < 1024; i = i + 1)
                mem[i] <= 8'b0;
        end else if (we) begin
            case (mode)
                3'b000: begin // SW
                    mem[a]   <= wd[7:0];
                    mem[a+1] <= wd[15:8];
                    mem[a+2] <= wd[23:16];
                    mem[a+3] <= wd[31:24];
                end
                3'b001, 3'b010: begin // SH
                    mem[a]   <= wd[7:0];
                    mem[a+1] <= wd[15:8];
                end
                3'b011, 3'b100: begin // SB
                    mem[a]   <= wd[7:0];
                end
            endcase
        end
    end
endmodule