#!/usr/bin/env python3
# based off of https://ghdl.github.io/ghdl-cosim/vhpidirect/dynamic.html

import ctypes
import _ctypes


class GHDLProgramExecutor(object):

    def __init__(self, ghdl_bin_path='bin/full_program_tb'):
        self.ghdl_bin_path = ghdl_bin_path

    def call_ghdl(self, program_file, scratchpad_file):
        try:
            ghdl_bin = ctypes.CDLL(self.ghdl_bin_path)
            args = [
                f'-gPROGRAM_FILE="{program_file}"',
                f'-gSCRATCHPAD_FILE="{scratchpad_file}"']
            xargs = (ctypes.POINTER(ctypes.c_char) * (len(args)+1))()
            for idx, arg in enumerate(args):
                xargs[idx+1] = ctypes.create_string_buffer(arg.encode('utf-8'))
            ghdl_bin.ghdl_main(len(xargs), xargs)
        finally:
            _ctypes.dlclose(ghdl_bin._handle)
            del ghdl_bin


def main():
    program_executor = GHDLProgramExecutor()
    program_executor.call_ghdl('program_file_path', 'scratchpad_file_path')


if __name__ == '__main__':
    main()
