
STACK_SIZE = $(shell ulimit -s)

GHDL_OPTIONS = -P/home/wwerst/proj/randx_fpga_private/osvvm --std=08 --workdir=work

.PHONY: all import fullprogram_tests continuous_tests documentation clean

all:
	sleep 1

import: clean
	mkdir -p work bin
	ghdl -i ${GHDL_OPTIONS} tests/*.vhd
	ghdl -i ${GHDL_OPTIONS} src/*.vhd

fullprogram_tests: import
	ghdl -m ${GHDL_OPTIONS} -o bin/full_program_tb.so full_program_tb
	ghdl -e ${GHDL_OPTIONS} -shared -Wl,-Wl,-u,ghdl_main -o bin/full_program_tb full_program_tb
	python3 tests/program_tb.py

loop_engine_tests: import
	ghdl -m ${GHDL_OPTIONS} -o bin/loop_engine_tb.so LoopEngineTB
	ghdl -e ${GHDL_OPTIONS} -shared -Wl,-Wl,-u,ghdl_main -o bin/loop_engine_tb LoopEngineTB
	python3 tests/loop_engine_tb.py

continuous_tests:
	fswatch -m poll_monitor -0 -o src/* | xargs -0 -n1 bash -c "clear && echo '*****************Running Tests***************************' && make cpu_fullprogram_tests"

documentation:
	rm -rf doxy_out
	doxygen docs/Doxyfile

clean:
	rm -r work/*.cf || true
	rm *.vcd        || true
	rm *.ghw        || true
