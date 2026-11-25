# Open-source simulation flow (GHDL). Synthesis is done in Xilinx ISE, see docs/ise_guide.md.

GHDL      ?= ghdl
GHDLFLAGS := --std=93 --workdir=build
STOP_TIME := 160us

RTL := rtl/x86_alu.vhd rtl/x86_exec.vhd rtl/pic_to_8086.vhd \
       rtl/uart_rx.vhd rtl/uart_tx.vhd rtl/emulator_top.vhd
TB  := sim/emulator_tb.vhd

.PHONY: all sim wave model clean

all: sim model

build:
	mkdir -p build

sim: build
	$(GHDL) -a $(GHDLFLAGS) $(RTL) $(TB)
	$(GHDL) -e $(GHDLFLAGS) emulator_tb
	$(GHDL) -r $(GHDLFLAGS) emulator_tb --stop-time=$(STOP_TIME) --assert-level=error \
		| tee build/sim.log
	grep -q "TEST PASSED" build/sim.log

wave: build
	$(GHDL) -a $(GHDLFLAGS) $(RTL) $(TB)
	$(GHDL) -e $(GHDLFLAGS) emulator_tb
	$(GHDL) -r $(GHDLFLAGS) emulator_tb --stop-time=$(STOP_TIME) --wave=build/emulator_tb.ghw
	@echo "Open build/emulator_tb.ghw with GTKWave"

model:
	cd model && python3 -m pytest -q

clean:
	rm -rf build
