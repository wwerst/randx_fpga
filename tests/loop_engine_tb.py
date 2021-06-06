#!/usr/bin/env python3

# loop_engine_tb.py
#
# This code generates test data for the loop engine,
# and then runs the loop engine.
#
#
# Author: Will Werst
# Date: May/June 2021

# based off of https://ghdl.github.io/ghdl-cosim/vhpidirect/dynamic.html

import ctypes
import _ctypes
import mmap

import random


def uint_to_hexline(val):
    assert isinstance(val, ctypes.c_uint64)
    return f"{val.value:016X}\n"


class GHDLProgramExecutor(object):

    def __init__(self, ghdl_bin_path='bin/loop_engine_tb'):
        self.ghdl_bin_path = ghdl_bin_path

    def call_ghdl(self, program_data, scratchpad_data):
        program_filename = 'program_data.hex'
        scratchpad_filename = 'scratchpad_init_data.hex'
        with open(program_filename, 'w+') as program_file:
            # Each program instruction is a line
            program_file.writelines(
                [uint_to_hexline(prog_inst) for prog_inst in program_data])
        with open(scratchpad_filename, 'w+') as scratchpad_file:
            # Each 8-byte section of scratchpad is a line
            scratchpad_file.writelines(
                [uint_to_hexline(word) for word in scratchpad_data])
        try:
            ghdl_bin = ctypes.CDLL(self.ghdl_bin_path)
            args = [
                f'-gPROGRAM_FILENAME={program_filename}',
                f'-gSCRATCHPAD_FILENAME={scratchpad_filename}']
            xargs = (ctypes.POINTER(ctypes.c_char) * (len(args)+1))()
            for idx, arg in enumerate(args):
                xargs[idx+1] = ctypes.create_string_buffer(arg.encode('utf-8'))
            ghdl_bin.ghdl_main(len(xargs), xargs)
        finally:
            _ctypes.dlclose(ghdl_bin._handle)
            del ghdl_bin


def main():
    program_length = 256
    scratchpad_length = 2097152 // 8
    program_executor = GHDLProgramExecutor()
    program_data = [ctypes.c_uint64(random.randint(0, 2**64 - 1)) for i in range(program_length)]
    scratchpad_data = [ctypes.c_uint64(random.randint(0, 2**64 - 1)) for i in range(scratchpad_length)]
    # scratchpad_data = [ctypes.c_uint64(scratchpad_length-i-1) for i in range(scratchpad_length)]
    program_executor.call_ghdl(
        program_data,
        scratchpad_data)


if __name__ == '__main__':
    main()
