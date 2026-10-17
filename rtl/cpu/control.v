module control (
    input wire [31:0] instr,
    input wire branch_taken,
    output reg [1:0] PCSel,
    output reg [1:0] RegSel,
    output reg [3:0] AluOp,
    output reg regWE,
    output reg memWE,
    output reg rs1Sel,
    output reg rs2Sel,
    output reg [2:0] memMode
);
    wire [6:0] opcode = instr[6:0];
    wire [2:0] funct3 = instr[14:12];
    wire [6:0] funct7 = instr[31:25];

    always @(*) begin
        // Valores padrão
        PCSel   = 2'b00; // PC + 4
        RegSel  = 2'b01; // Resultado ULA
        AluOp   = 4'b0000;
        regWE   = 1'b0;
        memWE   = 1'b0;
        rs1Sel  = 1'b0; // rdout1
        rs2Sel  = 1'b0; // rdout2
        memMode = 3'b000;

        case (opcode)
            // R-Type
            7'b011_0011: begin
                regWE  = 1'b1;
                rs1Sel = 1'b0;
                rs2Sel = 1'b0;
                RegSel = 2'b01;
                case (funct3)
                    3'b000: AluOp = (funct7[5]) ? 4'b0001 : 4'b0000; // SUB : ADD
                    3'b001: AluOp = 4'b0101; // SLL
                    3'b010: AluOp = 4'b1011; // SLT
                    3'b011: AluOp = 4'b1001; // SLTU
                    3'b100: AluOp = 4'b0100; // XOR
                    3'b101: AluOp = (funct7[5]) ? 4'b0111 : 4'b0110; // SRA : SRL
                    3'b110: AluOp = 4'b0011; // OR
                    3'b111: AluOp = 4'b0010; // AND
                endcase
            end

            // I-Type Aritmético
            7'b001_0011: begin
                regWE  = 1'b1;
                rs1Sel = 1'b0;
                rs2Sel = 1'b1; // ExtImm
                RegSel = 2'b01;
                case (funct3)
                    3'b000: AluOp = 4'b0000; // ADDI
                    3'b010: AluOp = 4'b1011; // SLTI
                    3'b011: AluOp = 4'b1001; // SLTIU
                    3'b100: AluOp = 4'b0100; // XORI
                    3'b110: AluOp = 4'b0011; // ORI
                    3'b111: AluOp = 4'b0010; // ANDI
                    3'b001: AluOp = 4'b0101; // SLLI
                    3'b101: AluOp = (funct7[5]) ? 4'b0111 : 4'b0110; // SRAI : SRLI
                endcase
            end

            // Load (LB, LH, LW, LBU, LHU)
            7'b000_0011: begin
                regWE   = 1'b1;
                rs1Sel  = 1'b0;
                rs2Sel  = 1'b1;
                AluOp   = 4'b0000; // ADD para calcular endereço
                RegSel  = 2'b00;   // DataMem
                case (funct3)
                    3'b000: memMode = 3'b100; // LB
                    3'b001: memMode = 3'b010; // LH
                    3'b010: memMode = 3'b000; // LW
                    3'b100: memMode = 3'b011; // LBU
                    3'b101: memMode = 3'b001; // LHU
                endcase
            end

            // Store (SB, SH, SW)
            7'b010_0011: begin
                memWE  = 1'b1;
                rs1Sel = 1'b0;
                rs2Sel = 1'b1;
                AluOp  = 4'b0000; // ADD para calcular endereço
                case (funct3)
                    3'b000: memMode = 3'b100; // SB
                    3'b001: memMode = 3'b010; // SH
                    3'b010: memMode = 3'b000; // SW
                endcase
            end

            // Branch (BEQ, BNE, BLT, BGE, BLTU, BGEU)
            7'b110_0011: begin
                rs1Sel = 1'b0;
                rs2Sel = 1'b0;
                PCSel  = branch_taken ? 2'b10 : 2'b00; // PC + Imm
                case (funct3)
                    3'b000: AluOp = 4'b1000; // EQ
                    3'b001: AluOp = 4'b1000; // EQ (tratado na tomada do branch)
                    3'b100: AluOp = 4'b1011; // SLT
                    3'b101: AluOp = 4'b1100; // SGTE
                    3'b110: AluOp = 4'b1001; // ULT
                    3'b111: AluOp = 4'b1010; // UGTE
                endcase
            end

            // LUI
            7'b011_0111: begin
                regWE  = 1'b1;
                RegSel = 2'b10; // ExtImm diretamente
            end

            // AUIPC
            7'b001_0111: begin
                regWE  = 1'b1;
                rs1Sel = 1'b1; // PC
                rs2Sel = 1'b1; // ExtImm
                AluOp  = 4'b0000; // ADD
                RegSel = 2'b01;
            end

            // JAL
            7'b110_1111: begin
                regWE  = 1'b1;
                RegSel = 2'b11; // PC + 4
                PCSel  = 2'b10; // PC + Imm
            end

            // JALR
            7'b110_0111: begin
                regWE  = 1'b1;
                RegSel = 2'b11; // PC + 4
                PCSel  = 2'b01; // AluResult (rs1 + Imm)
                rs1Sel = 1'b0;
                rs2Sel = 1'b1;
                AluOp  = 4'b0000; // ADD
            end
        endcase
    end
endmodule