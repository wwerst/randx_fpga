/* Test Script
 * 
 * This program reads in program_data.hex and scratchpad_init_data.hex, and
 * runs a single iteration of the program loop on the data, similar to
 * what part of the vm_interpreted.cpp file does.
 * This is then used to dump an expected scratchpad file output for use in testing.
 */

#include <iostream>
#include <fstream>
#include <string>
#include <sstream>
#include <stdexcept>

#include "crypto/randomx/instruction.hpp"
#include "crypto/randomx/bytecode_machine.hpp"

int main(int argc, char **argv) {
    std::ifstream infile("../../program_data.hex");
    std::string line;
    randomx::Instruction instructions[256];
    int prog_index = 0;
    while (std::getline(infile, line))
    {
        // See 5.1 in RandomX_specs.pdf
        // imm32, mod, src, dst, opcode   <= Struct order of instruction
        uint32_t imm32 = std::stol(line.substr(0, 8), 0, 16);
        uint8_t  mod   = std::stoi(line.substr(8, 2), 0, 16);
        uint8_t  src   = std::stoi(line.substr(10, 2), 0, 16);
        uint8_t  dst   = std::stoi(line.substr(12, 2), 0, 16);
        uint8_t  opcode = std::stoi(line.substr(14, 2), 0, 16);
        instructions[prog_index].imm32 = imm32;
        instructions[prog_index].mod   = mod;
        instructions[prog_index].src   = src;
        instructions[prog_index].dst   = dst;
        instructions[prog_index].opcode = opcode;
        std::cout << "Instruction " << prog_index << std::endl;
        std::cout << line << std::endl;
        std::cout << instructions[prog_index].imm32 << ", ";
        std::cout << unsigned(instructions[prog_index].mod) << ", ";
        std::cout << unsigned(instructions[prog_index].src) << ", ";
        std::cout << unsigned(instructions[prog_index].dst) << ", ";
        std::cout << unsigned(instructions[prog_index].opcode) << std::endl;
        // std::cout << unsigned(instructions[prog_index].mod) << std::endl;
        prog_index += 1;
    }
    return 0;
}
