"""Tests for the reference model. Run with:  python -m pytest model/"""

from reference_model import add8, run, translate

CF, ZF, SF, OF, AF = 0x01, 0x02, 0x04, 0x08, 0x10


def test_translate_addlw():
    assert translate(0x3E25) == bytes([0x04, 0x25])
    assert translate(0x3FC0) == bytes([0x04, 0xC0])   # 11 111x: bit 8 is don't-care


def test_translate_addwf():
    assert translate(0x0720) == bytes([0x02, 0x06, 0x20, 0x00])   # d = 0 -> AL
    assert translate(0x07A0) == bytes([0x00, 0x06, 0x20, 0x00])   # d = 1 -> memory
    assert translate(0x077F) == bytes([0x02, 0x06, 0x7F, 0x00])


def test_translate_unsupported_is_nop():
    for word in (0x3025, 0x0103, 0x01A0, 0x2806, 0x0000):
        assert translate(word) == bytes([0x90])


def test_flags():
    assert add8(0x4A, 0xC0) == (0x0A, CF)
    assert add8(0x00, 0x00) == (0x00, ZF)
    assert add8(0x7F, 0x01) == (0x80, SF | OF | AF)
    assert add8(0x80, 0x80) == (0x00, CF | ZF | OF)
    assert add8(0x0F, 0x01) == (0x10, AF)


def test_testbench_program():
    """Same instruction sequence and expected results as sim/emulator_tb.vhd."""
    stream, cpu = run([0x3E25, 0x07A0, 0x0720, 0x3EC0, 0x3025])
    assert stream == bytes.fromhex("04 25 00 06 20 00 02 06 20 00 04 C0 90")
    assert cpu.al == 0x0A
    assert cpu.memory[0x20] == 0x25
    assert cpu.flags == CF
