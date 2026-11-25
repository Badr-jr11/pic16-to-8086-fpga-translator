# Xilinx ISE flow (Spartan-3, XC3S200-4FT256)

Tested toolchain: **Xilinx ISE 9.1i**, Digilent Spartan-3 Starter Board.
Use a project path without spaces.

## 1. Create the project

`File → New Project`

| Setting | Value |
|---|---|
| Top-level source type | HDL |
| Family / Device / Package / Speed | Spartan3 / XC3S200 / FT256 / -4 |
| Synthesis tool | XST (VHDL/Verilog) |
| Simulator | ISE Simulator (VHDL/Verilog) |
| Preferred language | VHDL |

On **Add Existing Sources** add every file in `rtl/`, plus `sim/emulator_tb.vhd`
and `constraints/emulator_top.ucf` (tick *Copy to Project*). Set the file types:

- `emulator_tb.vhd` → *Simulation Only*
- all files in `rtl/` → *Synthesis/Implementation + Simulation*

## 2. Behavioural simulation

1. *Sources for:* **Behavioral Simulation**, select `emulator_tb`.
2. *Xilinx ISE Simulator → Simulate Behavioral Model → Properties*:
   set **Simulation Run Time = 150 us** (the default 1000 ns is too short).
3. Run the simulation. In the wave window set `pic_byte`, `x86_byte` and `led` to
   hexadecimal and zoom to full view.

The testbench checks itself. The console should end with
`TEST PASSED: all 13 bytes, AL = 0Ah, flags = 01h`.

Expected waveform milestones (UART sped up to 16 clocks/bit for simulation):

| Time | Sent (PIC) | Received on `x86_byte` (8086) | `led` |
|---|---|---|---|
| ~10–13 µs | `3E 25` ADDLW 0x25 | `04 25` | `42` |
| ~35–45 µs | `07 A0` ADDWF 0x20,F | `00 06 20 00` | `44` |
| ~61–71 µs | `07 20` ADDWF 0x20,W | `02 06 20 00` | `44` |
| ~87–90 µs | `3E C0` ADDLW 0xC0 | `04 C0` | `42` |
| ~112 µs | `30 25` MOVLW (unsupported) | `90` | `C1` |
| ~128–133 µs | `sw = 01` | — | `0A` (AL) |
| ~133–138 µs | `sw = 10` | — | `01` (CF = 1) |

## 3. Synthesis and implementation

1. *Sources for:* **Synthesis/Implementation**, right-click `emulator_top` → *Set as Top Module*.
2. *Synthesize – XST* → *View RTL Schematic* to inspect the hierarchy
   (`uart_rx`, `uart_tx`, `pic_to_8086`, `x86_exec`).
3. *Implement Design* → *Generate Programming File*, then program the board with iMPACT.

## 4. Cross-checking against the real tool-chains

### MPLAB (PIC16F887)

*Project Wizard* → device **PIC16F887**, toolsuite **Microchip MPASM**, add
`firmware/pic16/add_pic.asm` → *Build All*.

*View → Program Memory* opcodes: `0103 01A0 3E25 07A0 0720 3EC0 2806`.

Step through with **MPLAB SIM** (F7). Final state: `WREG = 0Ah`, `[20h] = 25h`, `STATUS.C = 1`.

### DOSBox (Intel 8086)

```
tasm /l add_8086.asm
tlink add_8086.obj
td add_8086.exe        ; F8 = step, final AL = 0Ah, CF = 1
```

`ADD_8086.LST` shows the machine code `04 25`, `00 06 0020`, `02 06 0020`, `04 C0`,
the same bytes the FPGA produces. Without TASM, use
`firmware/x86/add_8086_debug.txt` with `DEBUG.EXE`.
