
STACK_SIZE = $(shell ulimit -s)

.PHONY: all lst2test cpu_test_vector_files import alu_tests iau_tests dau_tests reg_tests

.PHONY: cpu_tests_all cpu_alu_tests cpu_data_move_tests cpu_flow_skip_tests cpu_flow_cond_branch_tests

.PHONY: cpu_flow_uncond_branch_tests continuous_tests clean

all:
	sleep 1

lst2test:
	gcc test_vectors/lst2test.c -o test_vectors/lst2test

cpu_test_vector_files: lst2test
	cd test_vectors; ./lst2test < alu_test_part1.lss > alu_test_part1_tv.txt
	cd test_vectors; ./lst2test < alu_test_part2.lss > alu_test_part2_tv.txt
	cd test_vectors; ./lst2test < data_move_test.lss > data_move_test_tv.txt
	cd test_vectors; ./lst2test < flow_skip.lss > flow_skip_tv.txt
	cd test_vectors; ./lst2test < flow_cond_branch.lss > flow_cond_branch_tv.txt
# 	cd test_vectors; ./lst2test < flow_uncond_branch.lss > flow_uncond_branch_tv.txt

import: clean
	mkdir -p work
	ghdl -i --std=08 --workdir=work src/*.vhd
	ghdl -i --std=08 --workdir=work src/alu/*.vhd
	ghdl -i --std=08 --workdir=work src/memunit/*.vhd
	ghdl -i --std=08 --workdir=work src/registers/*.vhd

alu_tests: import
	ghdl -m --std=08 --workdir=work alu_tb
	ghdl -r --std=08 --workdir=work alu_tb --vcd=avr_alu_tb.vcd

iau_tests: import
	ghdl -m --std=08 --workdir=work iau_tb
	ghdl -r --std=08 --workdir=work iau_tb --vcd=avr_iau_tb.vcd

dau_tests: import
	ghdl -m --std=08 --workdir=work dau_tb
	ghdl -r --std=08 --workdir=work dau_tb --vcd=avr_dau_tb.vcd

reg_tests: import
	ghdl -m --std=08 --workdir=work avr_reg_tb
	ghdl -r --std=08 --workdir=work avr_reg_tb --max-stack-alloc=$(STACK_SIZE) --vcd=avr_reg_tb.vcd

cpu_tests_all: cpu_fullprogram_tests
	sleep 1

cpu_fullprogram_tests: import
	ghdl -m --ieee=synopsys --std=08 --workdir=work cpu_programfull_tb 
	ghdl -r --ieee=synopsys --std=08 --workdir=work cpu_programfull_tb  --ieee-asserts=disable --wave=fullprogram_tb.ghw --vcd=fullprogram_tb.vcd

continuous_tests:
	fswatch -m poll_monitor -0 -o src/* | xargs -0 -n1 bash -c "clear && echo '*****************Running Tests***************************' && make cpu_fullprogram_tests"

clean:
	rm -r work/*.cf || true
	rm *.vcd        || true
	rm *.ghw        || true
