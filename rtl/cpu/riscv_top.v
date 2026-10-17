module riscv_top (
    input wire clk,
    input wire rst,
    
    // Sinais para observabilidade durante simulação e testes
    output wire [31:0] pc_out,
    output wire [31:0] instr_out,
    output wire [31:0] alu_result_out,
    output wire [31:0] reg_write_data_out,
    output wire [31:0] mem_write_data_out
);
    // Fios do PC e instrução
    wire [31:0] pc_curr, pc_next, pc_plus_4, pc_target;
    wire [31:0] instr;

    // Fios dos registradores e extensores
    wire [31:0] rdout1, rdout2, ext_imm;
    wire [31:0] alu_in_a, alu_in_b, alu_result;
    wire [31:0] mem_rd;
    wire [31:0] reg_wr_data;

    // Sinais de controle
    wire [1:0] PCSel, RegSel;
    wire [3:0] AluOp;
    wire regWE, memWE, rs1Sel, rs2Sel;
    wire [2:0] memMode;

    // Decisão do Branch
    wire [2:0] funct3 = instr[14:12];
    reg branch_taken;
    always @(*) begin
        if (instr[6:0] == 7'b110_0011) begin
            case (funct3)
                3'b000: branch_taken = (alu_result == 32'd1); // BEQ
                3'b001: branch_taken = (alu_result == 32'd0); // BNE
                3'b100, 3'b101, 3'b110, 3'b111: branch_taken = (alu_result == 32'd1);
                default: branch_taken = 1'b0;
            endcase
        end else begin
            branch_taken = 1'b0;
        end
    end

    // Saídas de monitoramento
    assign pc_out = pc_curr;
    assign instr_out = instr;
    assign alu_result_out = alu_result;
    assign reg_write_data_out = reg_wr_data;
    assign mem_write_data_out = rdout2;

    // Instanciação do PC
    pc pc_inst (
        .clk(clk),
        .rst(rst),
        .a(pc_next),
        .o(pc_curr)
    );

    // Somador PC + 4
    adder adder_pc4 (
        .a(pc_curr),
        .b(32'd4),
        .o(pc_plus_4)
    );

    // Somador PC + ExtImm (Desvios/Saltos)
    adder adder_pctarget (
        .a(pc_curr),
        .b(ext_imm),
        .o(pc_target)
    );

    // Mux do Próximo PC (PCSel)
    mux4 mux_pc (
        .s(PCSel),
        .a(pc_plus_4),
        .b(alu_result), // JALR
        .c(pc_target),   // Branch/JAL
        .d(32'b0),
        .o(pc_next)
    );

    // Memória de Instruções
    imem imem_inst (
        .addr(pc_curr),
        .inst(instr)
    );

    // Unidade de Controle
    control control_inst (
        .instr(instr),
        .branch_taken(branch_taken),
        .PCSel(PCSel),
        .RegSel(RegSel),
        .AluOp(AluOp),
        .regWE(regWE),
        .memWE(memWE),
        .rs1Sel(rs1Sel),
        .rs2Sel(rs2Sel),
        .memMode(memMode)
    );

    // Banco de Registradores
    regfile regfile_inst (
        .clk(clk),
        .rst(rst),
        .we(regWE),
        .rs1(instr[19:15]),
        .rs2(instr[24:20]),
        .rd(instr[11:7]),
        .wr_rd(reg_wr_data),
        .rs1_o(rdout1),
        .rs2_o(rdout2)
    );

    // Extensor de Imediato
    extendImm extend_inst (
        .Instr(instr),
        .ExtImm(ext_imm)
    );

    // Multiplexadores da ULA
    mux2 mux_rs1 (
        .s(rs1Sel),
        .a(pc_curr),
        .b(rdout1),
        .o(alu_in_a)
    );

    mux2 mux_rs2 (
        .s(rs2Sel),
        .a(ext_imm),
        .b(rdout2),
        .o(alu_in_b)
    );

    // Unidade Lógica Aritmética (ULA)
    ALU alu_inst (
        .a(alu_in_a),
        .b(alu_in_b),
        .ALUControl(AluOp),
        .result(alu_result)
    );

    // Memória de Dados
    dmem dmem_inst (
        .clk(clk),
        .reset(rst),
        .a(alu_result),
        .rd(mem_rd),
        .wd(rdout2),
        .we(memWE),
        .mode(memMode)
    );

    // Multiplexador de Escrita no Registrador (RegSel)
    mux4 mux_reg_write (
        .s(RegSel),
        .a(mem_rd),
        .b(alu_result),
        .c(ext_imm),
        .d(pc_plus_4),
        .o(reg_wr_data)
    );

endmodule