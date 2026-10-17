module extendImm (
    input wire [31:0] Instr,
    output reg [31:0] ExtImm
);
    wire [6:0] opcode = Instr[6:0];

    always @(*) begin
        case (opcode)
            // Tipo-I (LB, LH, LW, LBU, LHU, ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI, JALR)
            7'b000_0011, 7'b001_0011, 7'b110_0111: 
                ExtImm = {{20{Instr[31]}}, Instr[31:20]};
            
            // Tipo-S (SB, SH, SW)
            7'b010_0011: 
                ExtImm = {{20{Instr[31]}}, Instr[31:25], Instr[11:7]};
            
            // Tipo-B (BEQ, BNE, BLT, BGE, BLTU, BGEU)
            7'b110_0011: 
                ExtImm = {{19{Instr[31]}}, Instr[31], Instr[7], Instr[30:25], Instr[11:8], 1'b0};
            
            // Tipo-U (LUI, AUIPC)
            7'b011_0111, 7'b001_0111: 
                ExtImm = {Instr[31:12], 12'b0};
            
            // Tipo-J (JAL)
            7'b110_1111: 
                ExtImm = {{11{Instr[31]}}, Instr[31], Instr[19:12], Instr[20], Instr[30:21], 1'b0};
            
            default: ExtImm = 32'b0;
        endcase
    end
endmodule