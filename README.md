# PIC16F887 → Intel 8086 Hardware Instruction Translator (FPGA / VHDL)

A hardware binary translator on a **Xilinx Spartan-3 FPGA**. It receives
**PIC16F887** machine instructions over a UART, translates the addition
instructions to equivalent **Intel 8086** machine code, sends the 8086 bytes back
over the UART and **executes** them on a small 8086-style execution unit
(register `AL`, 128-byte data memory, `CF/ZF/SF/OF/AF` flags).

The design is written in synthesizable VHDL-93, verified with a self-checking
testbench, and cross-checked against MPLAB SIM (PIC) and Turbo Debugger (8086).

---

## Architecture

```
          RS-232 9600 8N1                                       RS-232
 PC ──rxd──► ┌─────────┐   2 bytes   ┌──────────────┐  1–4 bytes  ┌─────────┐ ──txd──► PC
             │ uart_rx │ ──────────► │ pic_to_8086  │ ──────────► │ uart_tx │
             └─────────┘  14-bit     │  (decoder)   │             └─────────┘
                          PIC word   └──────┬───────┘
                                            │ 8086 opcode / operands
                                     ┌──────▼───────┐
                                     │   x86_exec   │  AL, mem[0..127], flags
                                     │  └ x86_alu   │──────► LEDs (via sw[1:0])
                                     └──────────────┘
                 emulator_top: control FSM  HIGH → LOW → DECODE → SEND ⇄ WAIT
```

| Module | Description |
|---|---|
| `rtl/emulator_top.vhd` | Top level: assembles the 14-bit PIC word from two UART bytes, drives the decoder, executes the result and streams the 8086 bytes back |
| `rtl/pic_to_8086.vhd` | Combinational decoder, PIC16F887 instruction → 1–4 bytes of 8086 machine code |
| `rtl/x86_exec.vhd` | Execution unit: `AL` register, 128-byte memory (= PIC file registers), flags |
| `rtl/x86_alu.vhd` | 8-bit adder with 8086 `ADD` flag semantics (`CF`, `ZF`, `SF`, `OF`, `AF`) |
| `rtl/uart_rx.vhd`, `rtl/uart_tx.vhd` | 8N1 UART, baud rate set by the `CLKS_PER_BIT` generic (5208 → 9600 baud @ 50 MHz) |

## Translation table

| PIC16F887 | Encoding | Intel 8086 | Machine code |
|---|---|---|---|
| `ADDLW k` | `11 111x kkkk kkkk` | `ADD AL, k` | `04 kk` |
| `ADDWF f, W` (d = 0) | `00 0111 0fff ffff` | `ADD AL, [00ff]` | `02 06 ff 00` |
| `ADDWF f, F` (d = 1) | `00 0111 1fff ffff` | `ADD [00ff], AL` | `00 06 ff 00` |
| anything else | — | `NOP` (error flag set) | `90` |

Register mapping: PIC `W` ↔ 8086 `AL`, file register `f` ↔ memory byte `[00ffh]`.
`ModR/M = 06h` selects `mod=00, reg=AL, r/m=110` (direct 16-bit address).
The PIC `DC` flag maps to the 8086 `AF` flag.

## Board I/O (Digilent Spartan-3 Starter Board)

| Signal | Pin | Function |
|---|---|---|
| `clk` | T9 | 50 MHz oscillator |
| `rst` | L14 | BTN3, synchronous reset |
| `rxd` / `txd` | T13 / R13 | RS-232 DB9 |
| `sw[1:0]` | G12, F12 | LED view select |
| `led[7:0]` | P11 … K12 | see below |

| `sw` | LEDs show |
|---|---|
| `00` / `11` | `led7` = error (unsupported instruction), `led6` = result ready, `led2..0` = 8086 byte count |
| `01` | register `AL` |
| `10` | flags `000 AF OF SF ZF CF` |

## Verification

The same test program runs on all three platforms and gives the same result:

```asm
CLRW              ; W = 00h
CLRF   0x20       ; [20h] = 00h
ADDLW  0x25       ; W = 25h
ADDWF  0x20, F    ; [20h] = 25h
ADDWF  0x20, W    ; W = 4Ah
ADDLW  0xC0       ; W = 0Ah, C = 1
```

| Platform | Tool | Final state |
|---|---|---|
| PIC16F887 | MPLAB SIM | `W = 0Ah`, `[20h] = 25h`, `C = 1` |
| Intel 8086 | DOSBox + TASM / Turbo Debugger | `AL = 0Ah`, `[0020h] = 25h`, `CF = 1` |
| FPGA | `sim/emulator_tb.vhd` | 8086 stream `04 25 · 00 06 20 00 · 02 06 20 00 · 04 C0 · 90`, `AL = 0Ah`, flags `01h` |

**Self-checking testbench:** `sim/emulator_tb.vhd` drives PIC words into the UART,
decodes the serial reply, compares every byte against the expected 8086 code and
checks `AL` and the flags. It ends with `TEST PASSED` or `TEST FAILED`.

**Reference model:** `model/reference_model.py` is a bit-accurate Python model of
the decoder and execution unit, with unit tests that include flag corner cases
(signed overflow, auxiliary carry, zero result).

Both run in **GitHub Actions** on every push.

## Getting started

### Simulate with open-source tools

Requires [GHDL](https://github.com/ghdl/ghdl) and Python 3 with `pytest`.

```bash
make sim      # analyse, elaborate and run the self-checking testbench
make wave     # same, and dump build/emulator_tb.ghw for GTKWave
make model    # run the Python reference-model tests
```

### Build for the board (Xilinx ISE)

Step-by-step instructions for project setup, simulation in ISim, synthesis,
RTL schematic and bitstream generation, plus the MPLAB and DOSBox cross-checks,
are in [`docs/ise_guide.md`](docs/ise_guide.md).

## Repository layout

```
rtl/            synthesizable VHDL
sim/            self-checking testbench
constraints/    UCF pin constraints (Spartan-3 Starter Board)
firmware/pic16  PIC16F887 test program (MPASM)
firmware/x86    equivalent 8086 program (TASM) and DEBUG session script
model/          Python reference model and tests
docs/           Xilinx ISE / MPLAB / DOSBox walkthrough
```

## Possible extensions

- More PIC instructions (`SUBLW`, `SUBWF`, `ANDWF`, `IORWF`, `MOVLW` → `MOV AL, imm8`, …)
- Map PIC `STATUS` bits fully onto the 8086 `FLAGS` register
- Block-RAM program buffer to translate whole programs at once
- Port to a current device (Artix-7 / Vivado)
