/* Test Script
 * 
 * This program reads in program_data.hex and scratchpad_init_data.hex, and
 * runs a single iteration of the program loop on the data, similar to
 * what part of the vm_interpreted.cpp file does.
 * This is then used to dump an expected scratchpad file output for use in testing.
 */

#include <assert.h>
#include <iostream>
#include <fstream>
#include <string>
#include <sstream>
#include <stdexcept>

#include "crypto/randomx/randomx.h"
#include "crypto/randomx/common.hpp"
#include "crypto/randomx/instruction.hpp"
#include "crypto/randomx/virtual_machine.hpp"
#include "crypto/randomx/bytecode_machine.hpp"
#include "crypto/randomx/intrin_portable.h"
#include "crypto/randomx/program.hpp"


namespace randomx {

    template<int softAes>
    class TestVm : public BytecodeMachine {
    public:
        // using VmBase<softAes>::mem;
        // using VmBase<softAes>::scratchpad;
        // using VmBase<softAes>::program;
        // using VmBase<softAes>::config;
        // using VmBase<softAes>::reg;
        // using VmBase<softAes>::datasetPtr;
        // using VmBase<softAes>::datasetOffset;

        void* operator new(size_t, void* ptr) { return ptr; }
        void operator delete(void*) {}

    // protected:
    //     virtual void datasetRead(uint64_t blockNumber, int_reg_t(&r)[RegistersCount]);
    //     virtual void datasetPrefetch(uint64_t blockNumber);

    private:
        void execute();

        InstructionByteCode bytecode[RANDOMX_PROGRAM_MAX_SIZE];
    };

    using TestVmDefault = TestVm<1>;
    using TestVmHardAes = TestVm<0>;
}

namespace randomx {

    template<int softAes>
    void TestVm<softAes>::execute() {

    }

    using TestVmDefault = TestVm<1>;
    using TestVmHardAes = TestVm<0>;
}



int main(int argc, char **argv) {
    // Load program
    std::ifstream program_file("program_data.hex");
    std::string line;
    randomx::Instruction instructions[256];
    int prog_index = 0;
    while (std::getline(program_file, line))
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


    // Load scratchpad
    uint8_t* scratchpad = new uint8_t[2097152];
    std::ifstream scratchpad_init_file("scratchpad_init_data.hex");
    int scratchpad_index = 0;
    while (std::getline(scratchpad_init_file, line))
    {
        assert (line.size == 16);
        for (int byte_index = 0; byte_index < 8; byte_index++) {
            uint8_t byte_data = std::stoi(
                line.substr(byte_index*2, 2),
                0,
                16);
            scratchpad[scratchpad_index*8 + byte_index] = byte_data;
        }
        scratchpad_index += 1;
    }
    

    // Run program
    randomx::NativeRegisterFile nreg;
    randomx::Program program;
    // HACK(WHW): Modified program.hpp to allow copying in of new program
    std::copy(std::begin(instructions), std::end(instructions), std::begin(program.programBuffer));
    randomx::InstructionByteCode bytecode[256];
    std::cout << bytecode[255].imm << std::endl;
    randomx::TestVmDefault vm; // = new randomx::TestVmDefault();
    vm.compileProgram(program, bytecode, nreg);
    std::cout << bytecode[255].imm << std::endl;
    // randomx::compileProgram(program, bytecode, nreg);
    randomx::ProgramConfiguration program_config;
    vm.executeBytecode(bytecode, scratchpad, program_config);


    // Output scratchpad_final_data.hex
    std::ofstream scratchpad_final_file("scratchpad_final_data.hex");
    for (scratchpad_index = 0; scratchpad_index < 2097152 / 8; scratchpad_index++)
    {
        for (int byte_index = 0; byte_index < 8; byte_index++) {
            uint8_t byte_data = scratchpad[scratchpad_index*8 + byte_index];
            char dest[10];
            sprintf(dest, "%02X", byte_data);
            scratchpad_final_file << dest;
        }
        scratchpad_final_file << std::endl;
    }
    return 0;
}
