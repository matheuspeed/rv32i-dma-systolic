# =============================================================================
#  program.asm - Programa de teste do processador RISC-V single-cycle
#  Cada registrador termina com um valor diferente, conferido pelo testbench.
#  x17 marca erro: só é escrito se algum desvio tomar o caminho errado.
# =============================================================================

# --- Aritméticas e imediatos ------------------------------------------------
        addi  x1, x0, 10          # x1  = 10
        addi  x2, x0, -3          # x2  = -3 (0xFFFFFFFD)
        add   x3, x1, x2          # x3  = 7
        sub   x4, x2, x1          # x4  = -13 (0xFFFFFFF3)
        addi  x0, x0, 5           # x0 deve continuar 0

# --- LUI, lógicas e deslocamentos -------------------------------------------
        lui   x5, 0xF0F0F         # x5  = 0xF0F0F000
        ori   x5, x5, 0x0F0       # x5  = 0xF0F0F0F0
        andi  x6, x5, 0x0FF       # x6  = 0x000000F0
        xor   x7, x5, x2          # x7  = 0x0F0F0F0D
        srai  x8, x5, 4           # x8  = 0xFF0F0F0F (aritmético: entra 1)
        sll   x9, x1, x1          # x9  = 10 << 10 = 0x00002800

# --- Comparações e AUIPC ----------------------------------------------------
        slt   x10, x2, x1         # x10 = 1  (-3 < 10 com sinal)
        sltu  x11, x2, x1         # x11 = 0  (0xFFFFFFFD < 10 sem sinal: falso)
        auipc x12, 1              # x12 = PC + 0x1000 = 0x00001034

# --- Memória ----------------------------------------------------------------
        sw    x5, 256(x0)         # MEM[0x100] = 0xF0F0F0F0
        sb    x1, 257(x0)         # MEM[0x101] = 0x0A  -> palavra 0xF0F00AF0
        lw    x13, 256(x0)        # x13 = 0xF0F00AF0
        lb    x14, 256(x0)        # x14 = 0xFFFFFFF0 (byte F0 com sinal)
        lbu   x15, 256(x0)        # x15 = 0x000000F0 (byte F0 sem sinal)

# --- Desvios (tomados e não tomados, com e sem sinal) -----------------------
        beq   x1, x1, d1          # tomado
        jal   x0, erro
d1:     bne   x1, x1, erro        # não tomado
        blt   x2, x1, d2          # tomado     (-3 < 10 com sinal)
        jal   x0, erro
d2:     bltu  x2, x1, erro        # não tomado (0xFFFFFFFD < 10 sem sinal: falso)
        bge   x1, x2, d3          # tomado     (10 >= -3 com sinal)
        jal   x0, erro
d3:     bgeu  x1, x2, erro        # não tomado (10 >= 0xFFFFFFFD sem sinal: falso)

# --- Laço com desvio para trás: x16 = 1+2+3+4+5 -----------------------------
        addi  x16, x0, 0          # soma
        addi  x18, x0, 5          # contador
laco:   add   x16, x16, x18       # soma += contador
        addi  x18, x18, -1        # contador--
        bne   x18, x0, laco       # repete até zerar  -> x16 = 15, x18 = 0

# --- Chamada de função: JAL e JALR ------------------------------------------
        jal   x19, func           # x19 = endereço de retorno (0x00000088)
        sw    x20, 260(x0)        # MEM[0x104] = 77 (valor escrito pela função)
fim:    jal   x0, fim             # laço infinito: fim do programa

func:   addi  x20, x0, 77         # x20 = 77
        jalr  x0, 0(x19)          # retorna

erro:   addi  x17, x0, 1          # só executa se algum desvio falhar
        jal   x0, erro
