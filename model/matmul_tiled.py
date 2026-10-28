#!/usr/bin/env python3
"""
matmul_tiled.py - Modelo de referência (golden model) da multiplicação C = A x B
executada pelo sistema RV32I + DMA + systolic array.

O modelo segue as mesmas decisões de arquitetura do hardware:
  * A e B: inteiros de 8 bits com sinal (int8), armazenados em linha (row-major),
    4 elementos por palavra de 32 bits (little-endian)
  * C: inteiros de 32 bits com sinal (int32), uma palavra por elemento
  * Malha sistólica S x S (S = ARRAY_SIZE) do tipo output-stationary:
    cada MAC acumula um elemento de C; A entra pela esquerda, B entra por cima
  * Tiling: C é dividido em blocos S x S; K é percorrido em blocos de BUF_DEPTH
    (profundidade dos buffers locais). O acumulador só é zerado no primeiro
    bloco de K de cada bloco de C.

Há três níveis de referência, que precisam dar o mesmo resultado:
  1. matmul_ref       - multiplicação direta (três laços), a "verdade"
  2. matmul_tiled     - mesma conta organizada em blocos, na ordem do DMA
  3. systolic_tile    - simulação ciclo a ciclo da malha (dados atravessando
                        os registradores dos MACs), usada dentro do tiling

Uso:
  python matmul_tiled.py --selftest
      compara os três modelos para vários tamanhos e para S = 2, 4 e 8

  python matmul_tiled.py --m 16 --n 16 --k 16 --s 4 --out vetores
      gera os arquivos de teste para os testbenches (ver gera_vetores)
"""
import argparse
import os
import random

INT8_MIN, INT8_MAX = -128, 127
INT32_MIN, INT32_MAX = -(1 << 31), (1 << 31) - 1

# Mapa de memória padrão dos testes (endereços em bytes)
ADDR_A = 0x0400
ADDR_B = 0x0800
ADDR_C = 0x0C00
MEM_BYTES = 4096


def wrap32(v):
    """Comportamento de um registrador de 32 bits em complemento de 2."""
    v &= 0xFFFFFFFF
    return v - (1 << 32) if v & 0x80000000 else v


def check_dims(m, n, k, s):
    for nome, v in (('M', m), ('N', n), ('K', k)):
        if v <= 0 or v % s:
            raise ValueError(f'{nome}={v} precisa ser múltiplo de ARRAY_SIZE={s}')


# ---------------------------------------------------------------------------
# 1. Referência direta
# ---------------------------------------------------------------------------
def matmul_ref(A, B):
    m, k, n = len(A), len(B), len(B[0])
    return [[wrap32(sum(A[i][x] * B[x][j] for x in range(k))) for j in range(n)]
            for i in range(m)]


# ---------------------------------------------------------------------------
# 3. Malha sistólica output-stationary, ciclo a ciclo
# ---------------------------------------------------------------------------
def systolic_tile(a_tile, b_tile, acc, s):
    """
    Processa um bloco de K na malha S x S.

    a_tile: S linhas x KB colunas (conteúdo do Buffer A, um banco por linha)
    b_tile: KB linhas x S colunas (conteúdo do Buffer B, um banco por coluna)
    acc:    S x S acumuladores (alterados no lugar)

    A linha i de A entra pela esquerda da linha i da malha atrasada i ciclos;
    a coluna j de B entra por cima da coluna j atrasada j ciclos (skew). Cada
    MAC (i, j) multiplica o que chega, acumula e repassa A para a direita e
    B para baixo no ciclo seguinte.

    Retorna o número de ciclos gastos: KB + 2*(S-1).
    """
    kb = len(a_tile[0])
    a_reg = [[0] * s for _ in range(s)]   # valor de A guardado em cada MAC
    b_reg = [[0] * s for _ in range(s)]   # valor de B guardado em cada MAC
    ciclos = kb + 2 * (s - 1)
    for t in range(ciclos):
        # valores que entram nas bordas neste ciclo (com o atraso do skew)
        a_in = [a_tile[i][t - i] if 0 <= t - i < kb else 0 for i in range(s)]
        b_in = [b_tile[t - j][j] if 0 <= t - j < kb else 0 for j in range(s)]
        novo_a = [[0] * s for _ in range(s)]
        novo_b = [[0] * s for _ in range(s)]
        for i in range(s):
            for j in range(s):
                a = a_in[i] if j == 0 else a_reg[i][j - 1]   # vem da esquerda
                b = b_in[j] if i == 0 else b_reg[i - 1][j]   # vem de cima
                acc[i][j] = wrap32(acc[i][j] + a * b)
                novo_a[i][j], novo_b[i][j] = a, b
        a_reg, b_reg = novo_a, novo_b
    return ciclos


# ---------------------------------------------------------------------------
# 2. Multiplicação por blocos, na ordem em que o DMA trabalha
# ---------------------------------------------------------------------------
def matmul_tiled(A, B, s, buf_depth, sistolico=True):
    """
    Retorna (C, estatisticas). Com sistolico=True cada bloco é calculado pela
    simulação ciclo a ciclo da malha; com False, por soma direta.
    """
    m, k, n = len(A), len(B), len(B[0])
    check_dims(m, n, k, s)
    C = [[0] * n for _ in range(m)]
    est = dict(blocos_C=0, blocos_K=0, ciclos_malha=0)

    for ti in range(0, m, s):                    # linha de blocos de C
        for tj in range(0, n, s):                # coluna de blocos de C
            acc = [[0] * s for _ in range(s)]    # acc_clear
            for k0 in range(0, k, buf_depth):    # blocos de K
                kb = min(buf_depth, k - k0)
                # DMA: carrega Buffer A (S linhas) e Buffer B (S colunas)
                a_tile = [A[ti + i][k0:k0 + kb] for i in range(s)]
                b_tile = [B[k0 + x][tj:tj + s] for x in range(kb)]
                if sistolico:
                    est['ciclos_malha'] += systolic_tile(a_tile, b_tile, acc, s)
                else:
                    for i in range(s):
                        for j in range(s):
                            acc[i][j] = wrap32(acc[i][j] + sum(
                                a_tile[i][x] * b_tile[x][j] for x in range(kb)))
                est['blocos_K'] += 1
            # DMA: grava o bloco S x S de C na memória
            for i in range(s):
                for j in range(s):
                    C[ti + i][tj + j] = acc[i][j]
            est['blocos_C'] += 1
    return C, est


# ---------------------------------------------------------------------------
# Imagem de memória (como o hardware enxerga as matrizes)
# ---------------------------------------------------------------------------
def mem_image(A, B, C=None):
    mem = bytearray(MEM_BYTES)
    m, k, n = len(A), len(B), len(B[0])
    if ADDR_A + m * k > ADDR_B or ADDR_B + k * n > ADDR_C or ADDR_C + 4 * m * n > MEM_BYTES:
        raise ValueError('matrizes não cabem no mapa de memória padrão')
    for i in range(m):
        for x in range(k):
            mem[ADDR_A + i * k + x] = A[i][x] & 0xFF
    for x in range(k):
        for j in range(n):
            mem[ADDR_B + x * n + j] = B[x][j] & 0xFF
    if C is not None:
        for i in range(m):
            for j in range(n):
                mem[ADDR_C + 4 * (i * n + j):ADDR_C + 4 * (i * n + j) + 4] = \
                    (C[i][j] & 0xFFFFFFFF).to_bytes(4, 'little')
    return mem


def write_words(path, mem):
    """Uma palavra de 32 bits por linha, em hexadecimal (para $readmemh)."""
    with open(path, 'w') as f:
        for a in range(0, len(mem), 4):
            f.write(f'{int.from_bytes(mem[a:a + 4], "little"):08x}\n')


def write_matrix(path, M, bits):
    mask = (1 << bits) - 1
    w = bits // 4
    with open(path, 'w') as f:
        for linha in M:
            f.write(' '.join(f'{v & mask:0{w}x}' for v in linha) + '\n')


def rand_matrix(rows, cols, rng, lo=INT8_MIN, hi=INT8_MAX):
    return [[rng.randint(lo, hi) for _ in range(cols)] for _ in range(rows)]


# ---------------------------------------------------------------------------
def gera_vetores(m, n, k, s, buf_depth, seed, out):
    rng = random.Random(seed)
    A = rand_matrix(m, k, rng)
    B = rand_matrix(k, n, rng)
    C, est = matmul_tiled(A, B, s, buf_depth)
    assert C == matmul_ref(A, B), 'modelo em blocos diverge da referência!'

    os.makedirs(out, exist_ok=True)
    write_matrix(os.path.join(out, 'A.hex'), A, 8)
    write_matrix(os.path.join(out, 'B.hex'), B, 8)
    write_matrix(os.path.join(out, 'C_expected.hex'), C, 32)
    write_words(os.path.join(out, 'dmem_init.hex'), mem_image(A, B))
    write_words(os.path.join(out, 'dmem_expected.hex'), mem_image(A, B, C))
    with open(os.path.join(out, 'params.txt'), 'w') as f:
        f.write(f'M={m} N={n} K={k} ARRAY_SIZE={s} BUF_DEPTH={buf_depth} seed={seed}\n')
        f.write(f'ADDR_A=0x{ADDR_A:04X} ADDR_B=0x{ADDR_B:04X} ADDR_C=0x{ADDR_C:04X}\n')
        f.write(f'blocos de C={est["blocos_C"]}  blocos de K={est["blocos_K"]}  '
                f'ciclos na malha (sem contar o DMA)={est["ciclos_malha"]}\n')

    print(f'C = A x B  ({m}x{k} · {k}x{n}),  ARRAY_SIZE={s},  BUF_DEPTH={buf_depth}')
    print(f'{est["blocos_C"]} blocos de C, {est["blocos_K"]} passagens pela malha, '
          f'{est["ciclos_malha"]} ciclos de cálculo na malha')
    print(f'arquivos gerados em {out}/: A.hex B.hex C_expected.hex '
          f'dmem_init.hex dmem_expected.hex params.txt')


def selftest():
    rng = random.Random(2026)
    casos = 0
    for s in (2, 4, 8):
        for (m, n, k) in ((s, s, s), (8, 8, 8), (16, 16, 16), (8, 16, 24), (16, 8, 40)):
            if m % s or n % s or k % s:
                continue
            for buf in (s, 16):
                A = rand_matrix(m, k, rng)
                B = rand_matrix(k, n, rng)
                ref = matmul_ref(A, B)
                assert matmul_tiled(A, B, s, buf, sistolico=False)[0] == ref
                assert matmul_tiled(A, B, s, buf, sistolico=True)[0] == ref
                casos += 1
    # pior caso de magnitude: todos -128 -> produtos +16384, sem overflow para K=64
    A = [[-128] * 64 for _ in range(8)]
    B = [[-128] * 8 for _ in range(64)]
    assert matmul_tiled(A, B, 8, 16)[0][0][0] == 64 * 16384
    casos += 1
    print(f'selftest OK: {casos} casos (S = 2, 4 e 8), os três modelos concordam')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__.split('\n')[1])
    p.add_argument('--selftest', action='store_true')
    p.add_argument('--m', type=int, default=16)
    p.add_argument('--n', type=int, default=16)
    p.add_argument('--k', type=int, default=16)
    p.add_argument('--s', type=int, default=4, help='ARRAY_SIZE')
    p.add_argument('--buf', type=int, default=16, help='BUF_DEPTH')
    p.add_argument('--seed', type=int, default=1)
    p.add_argument('--out', default='vetores')
    a = p.parse_args()
    if a.selftest:
        selftest()
    else:
        gera_vetores(a.m, a.n, a.k, a.s, a.buf, a.seed, a.out)
