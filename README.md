# randx_fpga
RandomX FPGA Accelerator

## Documentation System

This project uses doxygen for generating documentation. See https://www.doxygen.nl/manual/docblocks.html#vhdlblocks

For Doxygen comment commands, see https://www.doxygen.nl/manual/commands.html


## Capitalization and style standards

Based off of https://www.alse-fr.com/sites/alse-fr.com/IMG/pdf/vhdl_coding_v4_eng.pdf

Use \_t suffix for types

Use Python conventions for capitalization, so:

- Entities -> Classes: CamelCase
- Ports -> variables: snake\_case
- Signals -> private variables: \_snake\_case
- Signals in port mappings: Can prefix with the unit being port-mapped. e.g. UUT\_some\_signal
- Types -> Structs: CamelCase_t

Arrays of records and other structs go from `(0 to n)`. std_logic_vector goes from `(n downto 0)`

Registers always go on outputs for RTL. Input registers should only be used for synchronizing signals.

Use active high resets, and do things on rising_edge(clk).

## Setup

### Sublime

Use the "Smart VHDL" package for good syntax highlighting and other IDE tools.