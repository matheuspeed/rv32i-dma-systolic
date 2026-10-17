# RV32I + DMA + Systolic Array

Sistema digital composto por um processador **RISC-V RV32I**, um **controlador de DMA** e um
**coprocessador de multiplicação matricial** baseado em *systolic array* parametrizável.
A CPU apenas configura e dispara a operação `C = A × B`; a movimentação dos dados e o cálculo
acontecem sem intervenção da CPU.

Projeto de front-end RTL (Verilog/SystemVerilog), verificação (UVM) e síntese lógica.
Ferramentas: Cadence Xcelium (simulação), SimVision (formas de onda) e Genus (síntese).

## Estrutura

```
docs/      especificação, mapa de memória, figuras, relatório e slides
rtl/       hardware
  include/   parâmetros e defines compartilhados
  cpu/       processador RV32I single-cycle
  mem/       memória de instruções e memória de dados compartilhada
  dma/       controlador de DMA
  accel/     unidades MAC e malha sistólica parametrizável
  top/       integração do sistema
sw/        software executado pelo processador
  cpu_tests/ programa de teste do processador (Assembly e .hex)
  firmware/  programa que configura o DMA e inicia a multiplicação
  tools/     montador Assembly → .hex
model/     modelo de referência (golden model) em Python
verif/     verificação
  unit/      testbenches unitários (cpu, accel, dma)
  uvm/       ambiente UVM do sistema integrado
sim/       Makefile, listas de arquivos e scripts de simulação
syn/       scripts, constraints e relatórios de síntese (um diretório por configuração)
```

## Como simular

Todos os comandos rodam de dentro de `sim/`:

```sh
cd sim
make cpu          # processador RV32I: testbench auto-verificável (PASSOU/FALHOU)
make cpu-waves    # idem, gravando as formas de onda e abrindo o SimVision
make clean
```

## Como gerar o .hex a partir do Assembly

```sh
python sw/tools/gen_tests.py sw/cpu_tests/program.asm
```

Gera `imem.hex` (e a listagem `program.lst` com o resultado esperado de cada instrução)
na mesma pasta do `.asm`.

## Entregas

| Entrega | Prazo | Conteúdo | Status |
|---|---|---|---|
| Trabalho prático: processador RISC-V | 01/11/2026 | CPU RV32I single-cycle, testbench, programa de teste, relatório | ✅ RTL e testes |
| Parcial 1 | 01/11/2026 | Repositório, diagrama de blocos, mapa de memória, interfaces, golden model | ⏳ |
| Parcial 2 | 14/11/2026 | RTL do MAC e da malha sistólica + testbench unitário (2×2 e 4×4) | ⏳ |
| Parcial 3 | 22/11/2026 | RTL do DMA e da memória compartilhada + testbench sem CPU | ⏳ |
| Parcial 4 | 13/12/2026 | Top-level, firmware e verificação UVM | ⏳ |
| Final | 18–19/12/2026 | Síntese de 3 configurações, relatório técnico e apresentação | ⏳ |

## Equipe

- 
- 
- 
- 
