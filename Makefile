
STACK_SIZE = $(shell ulimit -s)

.PHONY: all import fullprogram_tests continuous_tests clean

all:
	sleep 1

import: clean
	mkdir -p work bin
	ghdl -i --std=08 --workdir=work tests/*.vhd
# 	ghdl -i --std=08 --workdir=work src/*.vhd

# cpu_fullprogram_tests: import
# 	ghdl -m --ieee=synopsys --std=08 --workdir=work cpu_programfull_tb 
# 	ghdl -r --ieee=synopsys --std=08 --workdir=work cpu_programfull_tb  --ieee-asserts=disable --wave=fullprogram_tb.ghw --vcd=fullprogram_tb.vcd

fullprogram_tests: import
	ghdl -m --std=08 --workdir=work -o bin/full_program_tb.so full_program_tb
	ghdl -e -shared -Wl,-Wl,-u,ghdl_main --std=08 --workdir=work -o bin/full_program_tb full_program_tb
	python3 tests/program.py

continuous_tests:
	fswatch -m poll_monitor -0 -o src/* | xargs -0 -n1 bash -c "clear && echo '*****************Running Tests***************************' && make cpu_fullprogram_tests"

clean:
	rm -r work/*.cf || true
	rm *.vcd        || true
	rm *.ghw        || true
