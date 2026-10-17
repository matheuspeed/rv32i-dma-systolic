#!/usr/bin/env python3
"""
gen_tests.py - Montador + simulador de referência do RV32I.

Lê um programa .asm e gera, na mesma pasta:
  imem.hex            programa em hexadecimal (carregado pela imem com $readmemh)
  program.lst         listagem: endereço | hex | instrução | efeito esperado

Com --expected, gera também:
  expected_trace.txt  uma linha por instrução executada (PC, instrução,
                      escrita em registrador e escrita em memória)
  expected_regs.hex   valor esperado de x0..x31 ao final
  expected_dmem.hex   valor esperado dos 1024 bytes da memória de dados

O programa precisa terminar num laço infinito ("fim: jal x0, fim").

O modelo executa o programa decodificando o próprio imem.hex (e não o texto
do assembly), e o montador confere que cada palavra gerada decodifica de volta
para a instrução escrita. Assim um erro de codificação aparece aqui mesmo.

Uso:  python gen_tests.py [program.asm] [pasta_de_saida] [--expected]
"""
import re
import sys
import os

IMEM_WORDS = 256      # tamanho da imem (reg [31:0] mem [0:255])
DMEM_BYTES = 1024     # tamanho da dmem (reg [7:0] mem [0:1023])
MAX_STEPS = 10000     # proteção contra laço infinito inesperado

MASK = 0xFFFFFFFF

# ----------------------------------------------------------------------------
# Tabela de instruções: mnemônico -> (formato, opcode, funct3, funct7)
# ----------------------------------------------------------------------------
INSTR = {
    'lui':   ('U', 0b0110111, None, None),
    'auipc': ('U', 0b0010111, None, None),
    'jal':   ('J', 0b1101111, None, None),
    'jalr':  ('I', 0b1100111, 0b000, None),
    'beq':   ('B', 0b1100011, 0b000, None),
    'bne':   ('B', 0b1100011, 0b001, None),
    'blt':   ('B', 0b1100011, 0b100, None),
    'bge':   ('B', 0b1100011, 0b101, None),
    'bltu':  ('B', 0b1100011, 0b110, None),
    'bgeu':  ('B', 0b1100011, 0b111, None),
    'lb':    ('I', 0b0000011, 0b000, None),
    'lh':    ('I', 0b0000011, 0b001, None),
    'lw':    ('I', 0b0000011, 0b010, None),
    'lbu':   ('I', 0b0000011, 0b100, None),
    'lhu':   ('I', 0b0000011, 0b101, None),
    'sb':    ('S', 0b0100011, 0b000, None),
    'sh':    ('S', 0b0100011, 0b001, None),
    'sw':    ('S', 0b0100011, 0b010, None),
    'addi':  ('I', 0b0010011, 0b000, None),
    'slti':  ('I', 0b0010011, 0b010, None),
    'sltiu': ('I', 0b0010011, 0b011, None),
    'xori':  ('I', 0b0010011, 0b100, None),
    'ori':   ('I', 0b0010011, 0b110, None),
    'andi':  ('I', 0b0010011, 0b111, None),
    'slli':  ('SH', 0b0010011, 0b001, 0b0000000),
    'srli':  ('SH', 0b0010011, 0b101, 0b0000000),
    'srai':  ('SH', 0b0010011, 0b101, 0b0100000),
    'add':   ('R', 0b0110011, 0b000, 0b0000000),
    'sub':   ('R', 0b0110011, 0b000, 0b0100000),
    'sll':   ('R', 0b0110011, 0b001, 0b0000000),
    'slt':   ('R', 0b0110011, 0b010, 0b0000000),
    'sltu':  ('R', 0b0110011, 0b011, 0b0000000),
    'xor':   ('R', 0b0110011, 0b100, 0b0000000),
    'srl':   ('R', 0b0110011, 0b101, 0b0000000),
    'sra':   ('R', 0b0110011, 0b101, 0b0100000),
    'or':    ('R', 0b0110011, 0b110, 0b0000000),
    'and':   ('R', 0b0110011, 0b111, 0b0000000),
}
LOADS = {'lb', 'lh', 'lw', 'lbu', 'lhu'}
STORES = {'sb', 'sh', 'sw'}


def sext(v, bits):
    v &= (1 << bits) - 1
    return v - (1 << bits) if v >> (bits - 1) else v


def reg(tok):
    m = re.fullmatch(r'x(\d+)', tok.strip())
    if not m or not 0 <= int(m.group(1)) <= 31:
        raise ValueError(f'registrador inválido: {tok!r}')
    return int(m.group(1))


def num(tok):
    return int(tok.strip(), 0)


# ----------------------------------------------------------------------------
# Montador (duas passadas)
# ----------------------------------------------------------------------------
def parse(path):
    """Retorna lista de (linha_fonte, endereço, mnemônico, operandos) e labels."""
    lines, labels, pc = [], {}, 0
    for ln, raw in enumerate(open(path, encoding='utf-8'), 1):
        code = raw.split('#', 1)[0].strip()
        while True:
            m = re.match(r'^([A-Za-z_]\w*):\s*(.*)$', code)
            if not m:
                break
            if m.group(1) in labels:
                raise SystemExit(f'linha {ln}: label repetido {m.group(1)}')
            labels[m.group(1)] = pc
            code = m.group(2).strip()
        if not code:
            continue
        parts = code.split(None, 1)
        mn = parts[0].lower()
        ops = [o.strip() for o in parts[1].split(',')] if len(parts) > 1 else []
        if mn not in INSTR:
            raise SystemExit(f'linha {ln}: instrução não suportada: {mn}')
        lines.append((ln, pc, mn, ops, raw.rstrip('\n')))
        pc += 4
    return lines, labels


def target(tok, labels, pc):
    """Label -> deslocamento relativo ao PC; número -> deslocamento literal."""
    tok = tok.strip()
    if tok in labels:
        return labels[tok] - pc
    return num(tok)


def mem_operand(tok):
    m = re.fullmatch(r'(-?\w+)\s*\(\s*(x\d+)\s*\)', tok.strip())
    if not m:
        raise ValueError(f'operando de memória inválido: {tok!r}')
    return num(m.group(1)), reg(m.group(2))


def check_range(val, lo, hi, what, ln):
    if not lo <= val <= hi:
        raise SystemExit(f'linha {ln}: {what} {val} fora da faixa [{lo}, {hi}]')


def encode(ln, pc, mn, ops, labels):
    fmt, opc, f3, f7 = INSTR[mn]
    if fmt == 'R':
        rd, rs1, rs2 = reg(ops[0]), reg(ops[1]), reg(ops[2])
        return (f7 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | opc
    if fmt == 'SH':
        rd, rs1, sh = reg(ops[0]), reg(ops[1]), num(ops[2])
        check_range(sh, 0, 31, 'shamt', ln)
        return (f7 << 25) | (sh << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | opc
    if fmt == 'I':
        rd = reg(ops[0])
        if mn in LOADS or (mn == 'jalr' and len(ops) == 2):
            imm, rs1 = mem_operand(ops[1])
        else:
            rs1, imm = reg(ops[1]), num(ops[2])
        check_range(imm, -2048, 2047, 'imediato', ln)
        return ((imm & 0xFFF) << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | opc
    if fmt == 'S':
        rs2 = reg(ops[0])
        imm, rs1 = mem_operand(ops[1])
        check_range(imm, -2048, 2047, 'imediato', ln)
        imm &= 0xFFF
        return ((imm >> 5) << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | ((imm & 0x1F) << 7) | opc
    if fmt == 'B':
        rs1, rs2 = reg(ops[0]), reg(ops[1])
        off = target(ops[2], labels, pc)
        check_range(off, -4096, 4094, 'deslocamento', ln)
        if off & 1:
            raise SystemExit(f'linha {ln}: deslocamento ímpar')
        o = off & 0x1FFF
        return (((o >> 12) & 1) << 31) | (((o >> 5) & 0x3F) << 25) | (rs2 << 20) | (rs1 << 15) | \
               (f3 << 12) | (((o >> 1) & 0xF) << 8) | (((o >> 11) & 1) << 7) | opc
    if fmt == 'U':
        rd, imm = reg(ops[0]), num(ops[1])
        check_range(imm, 0, 0xFFFFF, 'imediato U', ln)
        return (imm << 12) | (rd << 7) | opc
    if fmt == 'J':
        rd = reg(ops[0])
        off = target(ops[1], labels, pc)
        check_range(off, -(1 << 20), (1 << 20) - 2, 'deslocamento', ln)
        o = off & 0x1FFFFF
        return (((o >> 20) & 1) << 31) | (((o >> 1) & 0x3FF) << 21) | (((o >> 11) & 1) << 20) | \
               (((o >> 12) & 0xFF) << 12) | (rd << 7) | opc
    raise AssertionError(fmt)


# ----------------------------------------------------------------------------
# Decodificador (independente do montador)
# ----------------------------------------------------------------------------
def decode(w):
    opc = w & 0x7F
    rd = (w >> 7) & 31
    f3 = (w >> 12) & 7
    rs1 = (w >> 15) & 31
    rs2 = (w >> 20) & 31
    f7 = w >> 25
    imm_i = sext(w >> 20, 12)
    imm_s = sext(((w >> 25) << 5) | ((w >> 7) & 31), 12)
    imm_b = sext((((w >> 31) & 1) << 12) | (((w >> 7) & 1) << 11) |
                 (((w >> 25) & 0x3F) << 5) | (((w >> 8) & 0xF) << 1), 13)
    imm_u = w & 0xFFFFF000
    imm_j = sext((((w >> 31) & 1) << 20) | (((w >> 12) & 0xFF) << 12) |
                 (((w >> 20) & 1) << 11) | (((w >> 21) & 0x3FF) << 1), 21)
    for mn, (fmt, o, ff3, ff7) in INSTR.items():
        if o != opc or (ff3 is not None and ff3 != f3):
            continue
        if fmt == 'R' and ff7 != f7:
            continue
        if fmt == 'SH' and ff7 != f7:
            continue
        d = dict(mn=mn, rd=rd, rs1=rs1, rs2=rs2)
        d['imm'] = {'R': 0, 'SH': rs2, 'I': imm_i, 'S': imm_s, 'B': imm_b,
                    'U': imm_u, 'J': imm_j}[fmt]
        return d
    raise ValueError(f'palavra não decodificável: {w:08x}')


def disasm(d, pc):
    mn, rd, rs1, rs2, imm = d['mn'], d['rd'], d['rs1'], d['rs2'], d['imm']
    fmt = INSTR[mn][0]
    if fmt == 'R':
        return f'{mn} x{rd}, x{rs1}, x{rs2}'
    if fmt == 'SH':
        return f'{mn} x{rd}, x{rs1}, {imm}'
    if mn in LOADS or mn == 'jalr':
        return f'{mn} x{rd}, {imm}(x{rs1})'
    if fmt == 'I':
        return f'{mn} x{rd}, x{rs1}, {imm}'
    if fmt == 'S':
        return f'{mn} x{rs2}, {imm}(x{rs1})'
    if fmt == 'B':
        return f'{mn} x{rs1}, x{rs2}, 0x{(pc + imm) & MASK:x}'
    if fmt == 'U':
        return f'{mn} x{rd}, 0x{imm >> 12:x}'
    if fmt == 'J':
        return f'{mn} x{rd}, 0x{(pc + imm) & MASK:x}'


def canon(mn, ops, pc, labels):
    """Forma canônica do texto escrito, para comparar com o disassembly."""
    fmt = INSTR[mn][0]
    if fmt == 'B':
        ops = ops[:2] + [f'0x{(pc + target(ops[2], labels, pc)) & MASK:x}']
    elif fmt == 'J':
        ops = ops[:1] + [f'0x{(pc + target(ops[1], labels, pc)) & MASK:x}']
    elif fmt == 'U':
        ops = [ops[0], f'0x{num(ops[1]):x}']
    elif mn in LOADS or mn in STORES or mn == 'jalr':
        if mn == 'jalr' and len(ops) == 3:
            ops = [ops[0], f'{num(ops[2])}({ops[1]})']
        else:
            imm, rs1 = mem_operand(ops[1])
            ops = [ops[0], f'{imm}(x{rs1})']
    elif fmt in ('I', 'SH'):
        ops = ops[:2] + [str(num(ops[2]))]
    return f'{mn} ' + ', '.join(o.replace(' ', '') for o in ops)


# ----------------------------------------------------------------------------
# Modelo de referência (ISS)
# ----------------------------------------------------------------------------
def run(words):
    x = [0] * 32
    mem = bytearray(DMEM_BYTES)
    pc = 0
    trace = []

    def ld(addr, n):
        if addr + n > DMEM_BYTES or addr < 0:
            raise SystemExit(f'PC={pc:#x}: load fora da dmem ({addr:#x})')
        return int.from_bytes(mem[addr:addr + n], 'little')

    for _ in range(MAX_STEPS):
        if pc >> 2 >= len(words):
            raise SystemExit(f'PC {pc:#x} saiu do programa')
        w = words[pc >> 2]
        d = decode(w)
        mn, rd, imm = d['mn'], d['rd'], d['imm']
        a, b = x[d['rs1']], x[d['rs2']]
        sa, sb = sext(a, 32), sext(b, 32)
        npc = (pc + 4) & MASK
        rwe, rval = 0, 0
        mwe, maddr, mdata, msize = 0, 0, 0, 0
        if mn == 'lui':
            rwe, rval = 1, imm
        elif mn == 'auipc':
            rwe, rval = 1, (pc + imm) & MASK
        elif mn == 'jal':
            rwe, rval, npc = 1, (pc + 4) & MASK, (pc + imm) & MASK
        elif mn == 'jalr':
            # Conforme a microarquitetura de referência (slide 37): o destino é
            # rs1+imm direto da ULA, sem zerar o bit 0.
            rwe, rval, npc = 1, (pc + 4) & MASK, (a + imm) & MASK
        elif INSTR[mn][0] == 'B':
            take = {'beq': a == b, 'bne': a != b, 'blt': sa < sb, 'bge': sa >= sb,
                    'bltu': a < b, 'bgeu': a >= b}[mn]
            if take:
                npc = (pc + imm) & MASK
        elif mn in LOADS:
            addr = (a + imm) & MASK
            n = {'lb': 1, 'lbu': 1, 'lh': 2, 'lhu': 2, 'lw': 4}[mn]
            v = ld(addr, n)
            if mn in ('lb', 'lh'):
                v = sext(v, 8 * n) & MASK
            rwe, rval = 1, v
        elif mn in STORES:
            addr = (a + imm) & MASK
            n = {'sb': 1, 'sh': 2, 'sw': 4}[mn]
            if addr + n > DMEM_BYTES:
                raise SystemExit(f'PC={pc:#x}: store fora da dmem ({addr:#x})')
            mem[addr:addr + n] = (b & ((1 << 8 * n) - 1)).to_bytes(n, 'little')
            mwe, maddr, mdata, msize = 1, addr, b, n
        else:
            if INSTR[mn][0] in ('R',):
                op2, sop2 = b, sb
            else:
                op2, sop2 = imm & MASK, sext(imm, 32)
            sh = op2 & 31
            rwe = 1
            base = mn[:-1] if mn.endswith('i') and mn not in ('srai',) else mn
            base = {'srai': 'sra', 'sltiu': 'sltu'}.get(mn, base)
            rval = {
                'add': a + op2, 'sub': a - op2, 'and': a & op2, 'or': a | op2,
                'xor': a ^ op2, 'sll': a << sh, 'srl': a >> sh, 'sra': sa >> sh,
                'slt': int(sa < sop2), 'sltu': int(a < (op2 & MASK)),
            }[base] & MASK
        if rwe and rd != 0:
            x[rd] = rval
        trace.append(dict(pc=pc, instr=w, rwe=rwe, rd=rd, rval=rval & MASK,
                          mwe=mwe, maddr=maddr, mdata=mdata & MASK, msize=msize,
                          d=d, x=None))
        if npc == pc:            # laço infinito "jal x0, 0": fim do programa
            return trace, x, mem
        pc = npc
    raise SystemExit('programa não terminou (falta o laço final "jal x0, label"?)')


# ----------------------------------------------------------------------------
def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    want_expected = '--expected' in sys.argv
    src = args[0] if len(args) > 0 else 'program.asm'
    out = args[1] if len(args) > 1 else os.path.dirname(os.path.abspath(src))
    lines, labels = parse(src)
    if len(lines) > IMEM_WORDS:
        raise SystemExit(f'programa com {len(lines)} instruções; a imem tem {IMEM_WORDS}')

    words = []
    for ln, pc, mn, ops, raw in lines:
        try:
            w = encode(ln, pc, mn, ops, labels)
        except (ValueError, IndexError) as e:
            raise SystemExit(f'linha {ln}: {e}\n  {raw}')
        # conferência de ida e volta: a palavra tem que decodificar de volta
        back = disasm(decode(w), pc)
        want = canon(mn, ops, pc, labels)
        if back != want:
            raise SystemExit(f'linha {ln}: codificação não confere\n  escrito: {want}\n  decodificado: {back}')
        words.append(w)

    trace, regs, mem = run(words)

    with open(os.path.join(out, 'imem.hex'), 'w') as f:
        f.writelines(f'{w:08x}\n' for w in words)
    if want_expected:
        write_expected(out, trace, regs, mem)
    write_listing(out, lines, words, labels, trace)

    used = sorted({t['d']['mn'] for t in trace})
    print(f'{len(words)} instruções no programa, {len(trace)} executadas até o laço final')
    print(f'{len(used)} de {len(INSTR)} tipos de instrução exercitados: {", ".join(used)}')
    print('arquivos gerados em', out)


def write_expected(out, trace, regs, mem):
    with open(os.path.join(out, 'expected_trace.txt'), 'w') as f:
        # pc instr reg_we rd reg_data mem_we mem_addr mem_data mem_bytes
        for t in trace:
            f.write(f"{t['pc']:08x} {t['instr']:08x} {t['rwe']} {t['rd']:02d} {t['rval']:08x} "
                    f"{t['mwe']} {t['maddr']:08x} {t['mdata']:08x} {t['msize']}\n")
    with open(os.path.join(out, 'expected_regs.hex'), 'w') as f:
        f.writelines(f'{r:08x}\n' for r in regs)
    with open(os.path.join(out, 'expected_dmem.hex'), 'w') as f:
        f.writelines(f'{b:02x}\n' for b in mem)


def write_listing(out, lines, words, labels, trace):
    # listagem com o efeito da PRIMEIRA execução de cada instrução
    first = {}
    for t in trace:
        first.setdefault(t['pc'], t)
    count = {}
    for t in trace:
        count[t['pc']] = count.get(t['pc'], 0) + 1
    addr_label = {v: k for k, v in labels.items()}
    with open(os.path.join(out, 'program.lst'), 'w', encoding='utf-8') as f:
        f.write('# endereço | hex      | instrução                      | efeito (1a execução)\n')
        for (ln, pc, mn, ops, raw), w in zip(lines, words):
            t = first.get(pc)
            if t is None:
                eff = '(não executada - caminho que não deve ser tomado)'
            else:
                eff = []
                if t['rwe']:
                    eff.append(f"x{t['rd']} <= 0x{t['rval']:08x}" + (' (ignorado: x0)' if t['rd'] == 0 else ''))
                if t['mwe']:
                    eff.append(f"MEM[0x{t['maddr']:03x}] <= 0x{t['mdata'] & ((1 << 8 * t['msize']) - 1):0{2 * t['msize']}x} ({t['msize']} B)")
                if count[pc] > 1:
                    eff.append(f'(executada {count[pc]}x)')
                eff = '  '.join(eff)
            lab = f"{addr_label[pc]}:" if pc in addr_label else ''
            f.write(f'{pc:08x}   {w:08x}   {lab:<6}{disasm(decode(w), pc):<28} {eff}\n')


if __name__ == '__main__':
    main()
