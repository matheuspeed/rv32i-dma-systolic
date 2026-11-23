.section .text
.globl _start
_start:
    lui  x10, 0x10          # x10 = 0x00010000 (base MMIO DMA)
    addi x11, x0, 0         # x11 = 0x00000000 (descritor DMEM)

    lw   x5, 0(x11)         # ADDR_A -> 0x08(x10)
    sw   x5, 8(x10)
    lw   x5, 4(x11)         # ADDR_B -> 0x0C(x10)
    sw   x5, 12(x10)
    lw   x5, 8(x11)         # ADDR_C -> 0x10(x10)
    sw   x5, 16(x10)
    lw   x5, 12(x11)        # DIM_M  -> 0x14(x10)
    sw   x5, 20(x10)
    lw   x5, 16(x11)        # DIM_N  -> 0x18(x10)
    sw   x5, 24(x10)
    lw   x5, 20(x11)        # DIM_K  -> 0x1C(x10)
    sw   x5, 28(x10)

    lw   x5, 24(x11)        # IRQ_EN (0 ou 1)
    slli x5, x5, 1          # bit 1 = IRQ_EN
    ori  x5, x5, 1          # bit 0 = START = 1
    sw   x5, 0(x10)         # escreve CTRL (0x00)

poll:
    lw   x6, 4(x10)         # lê STATUS (0x04)
    andi x6, x6, 2          # isola bit 1 (DONE)
    beq  x6, x0, poll       # aguarda DONE == 1

    addi x5, x0, 1          # sinaliza conclusão do firmware em DMEM[0x1C]
    sw   x5, 28(x11)

done:
    jal  x0, done           # loop infinito (mesma instrução usada no program.asm!)