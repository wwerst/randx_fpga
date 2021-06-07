
STACK_SIZE = $(shell ulimit -s)

GHDL_OPTIONS = -Posvvm --std=08 --workdir=work

.PHONY: all import fullprogram_tests continuous_tests documentation clean

.PHONY: xmrig_test_bench_clean xmrig_test_bench_rebuild xmrig_test_bench_build

all:
	sleep 1

import: clean
	mkdir -p work bin
	ghdl -i ${GHDL_OPTIONS} tests/*.vhd
	ghdl -i ${GHDL_OPTIONS} src/*.vhd
	ghdl -i ${GHDL_OPTIONS} src/alu/*.vhd
	ghdl -i ${GHDL_OPTIONS} src/loop_engine/*.vhd
	ghdl -i ${GHDL_OPTIONS} src/hash_engine/*.vhd

loop_engine_tests: import
	ghdl -m ${GHDL_OPTIONS} -o bin/loop_engine_tb.so LoopEngineTB
	ghdl -e ${GHDL_OPTIONS} -shared -Wl,-Wl,-u,ghdl_main -o bin/loop_engine_tb LoopEngineTB
	python3 tests/loop_engine_tb.py

float_alu_tests: import
	ghdl -m ${GHDL_OPTIONS} FloatALUTB
	ghdl -r ${GHDL_OPTIONS} FloatALUTB --wave=float_alu_tests.ghw --vcd=float_alu_tests.vcd

int_alu_tests: import
	ghdl -m ${GHDL_OPTIONS} IntALUTB
	ghdl -r ${GHDL_OPTIONS} IntALUTB --wave=int_alu_tests.ghw --vcd=int_alu_tests.vcd

continuous_tests:
	fswatch -m poll_monitor -0 -o src/* | xargs -0 -n1 bash -c "clear && echo '*****************Running Tests***************************' && make cpu_fullprogram_tests"

xmrig_test_bench_clean:
	cd xmrig_copied_src && rm -rf build && mkdir build

xmrig_test_bench_rebuild: xmrig_test_bench_clean
	cd xmrig_copied_src/build && cmake .. && make -j24

xmrig_test_bench_build:
	cd xmrig_copied_src/build && cmake .. && make -j24

documentation:
	rm -rf doxy_out
	doxygen docs/Doxyfile

clean:
	rm -r work/*.cf || true
	rm *.vcd        || true
	rm *.ghw        || true
