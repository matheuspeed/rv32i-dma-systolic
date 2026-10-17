`timescale 1ns / 1ps

module tb_riscv;

    reg clk;
    reg rst;

    wire [31:0] pc;
    wire [31:0] instr;
    wire [31:0] alu_result;
    wire [31:0] reg_write_data;
    wire [31:0] mem_write_data;

    integer erros;
    integer ciclos;

    // Instanciação do Processador RISC-V Top
    riscv_top uut (
        .clk(clk),
        .rst(rst),
        .pc_out(pc),
        .instr_out(instr),
        .alu_result_out(alu_result),
        .reg_write_data_out(reg_write_data),
        .mem_write_data_out(mem_write_data)
    );

    // Geração do Sinal de Clock (Período = 10ns -> 100MHz)
    always #5 clk = ~clk;

    // Compara um registrador com o valor esperado
    task check_reg;
        input [4:0]  r;
        input [31:0] esperado;
        begin
            if (uut.regfile_inst.mem[r] === esperado)
                $display("  x%0d\t= %08h   OK", r, uut.regfile_inst.mem[r]);
            else begin
                $display("  x%0d\t= %08h   ERRO (esperado %08h)", r, uut.regfile_inst.mem[r], esperado);
                erros = erros + 1;
            end
        end
    endtask

    // Compara uma palavra da memória de dados com o valor esperado
    task check_mem;
        input [9:0]  a;
        input [31:0] esperado;
        reg   [31:0] lido;
        begin
            lido = {uut.dmem_inst.mem[a+3], uut.dmem_inst.mem[a+2],
                    uut.dmem_inst.mem[a+1], uut.dmem_inst.mem[a]};
            if (lido === esperado)
                $display("  MEM[%03h] = %08h   OK", a, lido);
            else begin
                $display("  MEM[%03h] = %08h   ERRO (esperado %08h)", a, lido, esperado);
                erros = erros + 1;
            end
        end
    endtask

    initial begin
        // Inicialização de sinais
        clk   = 0;
        rst   = 1;
        erros = 0;

        // Reset liberado na borda de descida (longe da borda de subida)
        #15;
        @(negedge clk);
        rst = 0;

        $display("-----------------------------------------------------------------------");
        $display(" Tempo(ns) |   PC     | Instrução | Result ULA | Escrita Reg | Escrita Mem ");
        $display("-----------------------------------------------------------------------");
        $monitor("%8t   | %08h | %08h  |  %08h  |   %08h  |  %08h",
                 $time, pc, instr, alu_result, reg_write_data, mem_write_data);

        // Executa até o PC chegar ao laço final (0x8C), com limite de 200 ciclos
        ciclos = 0;
        while (pc !== 32'h0000008C && ciclos < 200) begin
            @(negedge clk);
            ciclos = ciclos + 1;
        end
        @(negedge clk);
        $monitoroff;

        $display("-----------------------------------------------------------------------");
        $display("VERIFICAÇÃO DOS REGISTRADORES:");
        check_reg( 0, 32'h00000000);  // escrita em x0 ignorada
        check_reg( 1, 32'h0000000A);  // addi
        check_reg( 2, 32'hFFFFFFFD);  // addi com imediato negativo
        check_reg( 3, 32'h00000007);  // add
        check_reg( 4, 32'hFFFFFFF3);  // sub com resultado negativo
        check_reg( 5, 32'hF0F0F0F0);  // lui + ori
        check_reg( 6, 32'h000000F0);  // andi
        check_reg( 7, 32'h0F0F0F0D);  // xor
        check_reg( 8, 32'hFF0F0F0F);  // srai (aritmético)
        check_reg( 9, 32'h00002800);  // sll
        check_reg(10, 32'h00000001);  // slt  (com sinal)
        check_reg(11, 32'h00000000);  // sltu (sem sinal)
        check_reg(12, 32'h00001034);  // auipc
        check_reg(13, 32'hF0F00AF0);  // sw + sb + lw
        check_reg(14, 32'hFFFFFFF0);  // lb  (com sinal)
        check_reg(15, 32'h000000F0);  // lbu (sem sinal)
        check_reg(16, 32'h0000000F);  // laço: 1+2+3+4+5
        check_reg(17, 32'h00000000);  // nenhum desvio errado
        check_reg(18, 32'h00000000);  // contador do laço
        check_reg(19, 32'h00000088);  // jal: endereço de retorno
        check_reg(20, 32'h0000004D);  // escrito dentro da função (77)

        $display("VERIFICAÇÃO DA MEMÓRIA:");
        check_mem(10'h100, 32'hF0F00AF0);  // sw seguido de sb no byte 1
        check_mem(10'h104, 32'h0000004D);  // sw depois do retorno da função

        $display("VERIFICAÇÃO DO PC:");
        if (pc === 32'h0000008C)
            $display("  PC = %08h   OK (parado no laço final)", pc);
        else begin
            $display("  PC = %08h   ERRO (esperado 0000008C)", pc);
            erros = erros + 1;
        end

        $display("-----------------------------------------------------------------------");
        if (erros == 0) $display(">>> TESTE PASSOU <<<");
        else            $display(">>> TESTE FALHOU: %0d erro(s) <<<", erros);
        $display("-----------------------------------------------------------------------");

        $finish;
    end

endmodule
