# randx_fpga
RandomX FPGA Accelerator

## Folder Documentation

### .github

This contains Github actions automation scripts

### docs

This contains various documentation resources, such as the Randomx_Specs.pdf

### python_analysis

This is not relevant for EE119c. It is a folder containing some scripts that were
used to look at dependencies of instructions, but stale now.

### src

This contains source code for the VHDL implementation.

### tests

This contains VHDL test benches for code in the source code folder.

### xmrig_copied_src

This is a folder that is modified from a copy of https://github.com/xmrig/xmrig

It is used to generate oracle program outputs for test benches.

## Documentation System

This project uses doxygen for generating some of its documentation. See https://www.doxygen.nl/manual/docblocks.html#vhdlblocks

For Doxygen comment commands, see https://www.doxygen.nl/manual/commands.html


## Capitalization and style standards

Based off of https://www.alse-fr.com/sites/alse-fr.com/IMG/pdf/vhdl_coding_v4_eng.pdf

Use \_t suffix for types

Use Python conventions for capitalization, so:

- Entities -> Classes: CamelCase
- Ports -> variables: snake\_case
- Signals -> private variables: snake\_case_s
- Signals in port mappings: Can prefix with the unit being port-mapped. e.g. UUT\_some\_signal
- Types -> Structs: CamelCase_t

Arrays of records and other structs go from `(0 to n)`. std_logic_vector goes from `(n downto 0)`

Registers always go on outputs for RTL. Input registers should only be used for synchronizing signals.

Use active high resets, and do things on rising_edge(clk).

## Setup

### GHDL

Follow the install instructions in `run_ghdl_tests.yml`. For Ubuntu 20.04 there are some changes:

Error: No clang++. The install of llvm only adds clang++-10 and other numbered versions. Add symlink with `sudo ln -s /usr/bin/clang++-10 /usr/bin/clang++`, and similar for other llvm stuff.

Error: No `zlib.h`. See https://github.com/ghdl/ghdl/issues/248. `sudo apt install zlib1g-dev`.

### Sublime

Use the "Smart VHDL" package for good syntax highlighting and other IDE tools.

Also recommend installing Terminus for terminals in Sublime, and sublimelinter-flake8 for python syntax checking
