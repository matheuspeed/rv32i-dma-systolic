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

## Modelo de referência (golden model)

O arquivo [`model/matmul_tiled.py`](model/matmul_tiled.py) calcula `C = A × B` exatamente
como o hardware vai calcular, e é a referência contra a qual os testbenches comparam o
resultado. Escrito em Python puro (sem bibliotecas externas).

### Premissas (as mesmas do hardware)

| Item | Valor |
|---|---|
| Elementos de A e B | inteiros de 8 bits com sinal (int8), armazenados por linha, 4 por palavra de 32 bits |
| Elementos de C | inteiros de 32 bits com sinal (int32), um por palavra |
| Malha sistólica | `ARRAY_SIZE × ARRAY_SIZE` MACs, *output-stationary* |
| Tiling | C dividido em blocos `ARRAY_SIZE × ARRAY_SIZE`; K percorrido em blocos de `BUF_DEPTH` |
| Dimensões | M, N e K múltiplos de `ARRAY_SIZE` |

### Três níveis de modelo

```
matmul_ref      multiplicação direta (três laços) .................. a referência
     ║  têm que dar o mesmo resultado
matmul_tiled    mesma conta em blocos, na ordem em que o DMA trabalha
     ║  usa, para cada bloco
systolic_tile   malha simulada ciclo a ciclo: A entra pela esquerda,
                B por cima, com atraso escalonado (skew); cada MAC
                multiplica, acumula e repassa os dados ao vizinho
```

Cada passagem de um bloco de K pela malha leva `BUF_DEPTH + 2·(ARRAY_SIZE − 1)` ciclos.
Os acumuladores só são zerados (`acc_clear`) na primeira passagem de cada bloco de C;
as passagens seguintes continuam somando.

### Como usar

```sh
python model/matmul_tiled.py --selftest   # compara os três modelos em 29 casos (S = 2, 4 e 8)
python model/matmul_tiled.py --demo       # exemplo 4×4 numa malha 2×2, passo a passo
python model/matmul_tiled.py --m 16 --n 16 --k 16 --s 4 --out vetores   # gera vetores de teste
```

- **`--selftest`**: tabela com, para cada caso, número de blocos, passagens pela malha,
  ciclos de cálculo e se os três modelos concordam. Inclui o pior caso de magnitude
  (todos os elementos −128), que confirma que o acumulador de 32 bits não estoura.
- **`--demo`**: mostra a sequência de blocos que o DMA percorre e o estado de cada MAC
  ciclo a ciclo — serve de referência para conferir as formas de onda da malha em Verilog.
- **Geração de vetores** (opções `--m --n --k --s --buf --seed --out`):

| Arquivo gerado | Conteúdo | Usado em |
|---|---|---|
| `A.hex`, `B.hex` | matrizes de entrada (int8, hexadecimal) | testbench da malha |
| `C_expected.hex` | resultado esperado (int32) | testbench da malha |
| `dmem_init.hex` | memória inicial: A em `0x400`, B em `0x800` (uma palavra por linha) | testbenches do DMA e do sistema |
| `dmem_expected.hex` | memória esperada ao final, com C em `0xC00` | testbenches do DMA e do sistema |
| `params.txt` | dimensões, endereços e contagem de ciclos | — |

### Exemplo de resultado (`--selftest`, matriz 16×16×16)

| ARRAY_SIZE | Blocos de C | Ciclos de cálculo na malha |
|---|---|---|
| 2×2 | 64 | 1152 |
| 4×4 | 16 | 352 |
| 8×8 | 4 | 120 |

(`BUF_DEPTH = 16`; contagem apenas da malha, sem o tempo de transferência do DMA.)

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
| Parcial 1 | 01/11/2026 | Repositório, diagrama de blocos, mapa de memória, interfaces, golden model | ✅ repositório e golden model · ⏳ especificação |
| Parcial 2 | 14/11/2026 | RTL do MAC e da malha sistólica + testbench unitário (2×2 e 4×4) | ⏳ |
| Parcial 3 | 22/11/2026 | RTL do DMA e da memória compartilhada + testbench sem CPU | ⏳ |
| Parcial 4 | 13/12/2026 | Top-level, firmware e verificação UVM | ⏳ |
| Final | 18–19/12/2026 | Síntese de 3 configurações, relatório técnico e apresentação | ⏳ |

## Equipe

- 
- 
- 
-