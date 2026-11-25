"""Bit-accurate Python reference model of the PIC16F887 -> Intel 8086 translator.

Mirrors the behaviour of rtl/pic_to_8086.vhd (decoder) and rtl/x86_exec.vhd +
rtl/x86_alu.vhd (execution unit), so the hardware can be checked against an
independent golden model.
"""

from dataclasses import dataclass, field

NOP = 0x90


def translate(pic_code: int) -> bytes:
    """Translate one 14-bit PIC16F887 instruction word into 8086 machine code."""
    pic_code &= 0x3FFF
    if (pic_code >> 9) == 0b11111:                      # ADDLW k  -> ADD AL, imm8
        return bytes([0x04, pic_code & 0xFF])
    if (pic_code >> 8) == 0b000111:                     # ADDWF f,d
        addr = pic_code & 0x7F
        opcode = 0x00 if pic_code & 0x80 else 0x02      # d=1: ADD [f],AL  d=0: ADD AL,[f]
        return bytes([opcode, 0x06, addr, 0x00])
    return bytes([NOP])                                 # unsupported -> NOP


def add8(a: int, b: int):
    """8-bit ADD with the 8086 flags. Returns (result, flags).

    flags byte layout (as in the RTL): 000 AF OF SF ZF CF
    """
    total = a + b
    result = total & 0xFF
    cf = total >> 8
    zf = int(result == 0)
    sf = result >> 7
    of = int(((a ^ result) & (b ^ result) & 0x80) != 0)
    af = int(((a & 0x0F) + (b & 0x0F)) > 0x0F)
    return result, (af << 4) | (of << 3) | (sf << 2) | (zf << 1) | cf


@dataclass
class X86Exec:
    """Execution unit: AL, 128-byte memory, flags."""

    al: int = 0
    flags: int = 0
    memory: list = field(default_factory=lambda: [0] * 128)

    def execute(self, code: bytes) -> None:
        op = code[0]
        if op == 0x04:                                  # ADD AL, imm8
            self.al, self.flags = add8(self.al, code[1])
        elif op == 0x02:                                # ADD AL, [addr]
            self.al, self.flags = add8(self.al, self.memory[code[2] & 0x7F])
        elif op == 0x00:                                # ADD [addr], AL
            addr = code[2] & 0x7F
            self.memory[addr], self.flags = add8(self.al, self.memory[addr])
        # NOP: no change


def run(program):
    """Translate and execute a list of PIC instruction words.

    Returns (8086 byte stream, final execution unit state).
    """
    cpu = X86Exec()
    stream = bytearray()
    for word in program:
        code = translate(word)
        stream += code
        cpu.execute(code)
    return bytes(stream), cpu


if __name__ == "__main__":
    demo = [0x3E25, 0x07A0, 0x0720, 0x3EC0, 0x3025]
    out, cpu = run(demo)
    print("8086 bytes:", out.hex(" ").upper())
    print(f"AL = {cpu.al:02X}h  [0020h] = {cpu.memory[0x20]:02X}h  flags = {cpu.flags:02X}h")
