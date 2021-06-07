---- Ignore this file

----------------------------------------
--! @file
--! @brief Not used right now. Framework for ull program testbench for the future
--! @author Will Werst
--! @date   May 2021
----------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

library osvvm;
use osvvm.AlertLogPkg.all;

-- Full program testbench
-- Called from program_tb.py
-- Not current used.
entity full_program_tb is
    generic (
        program_filename    : string;
        scratchpad_filename : string
    );
end full_program_tb;


architecture testbench of full_program_tb is

    constant CLK_PERIOD : time := 1 ms;
    signal done : boolean := FALSE;
    signal clk : std_logic := '0';

    type prog_inst_arr_t is array (0 to 255) of std_logic_vector(63 downto 0);

    type scratchpad_arr_t is array (0 to (2097152/8)-1) of std_logic_vector(63 downto 0);

    signal ProgInstructions : prog_inst_arr_t;
    signal Scratchpad       : scratchpad_arr_t;

    function to_hex(slv : std_logic_vector) return string is
        variable l : line;
    begin
        hwrite(l, slv);
        return l.all;
    end to_hex;

begin
    CLOCK_PROC: process begin
        while not done loop
            clk <= '0';
            wait for CLK_PERIOD/2;
            clk <= '1';
            wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process CLOCK_PROC;

    TEST_PROC: process
        file program_file    : text is program_filename;
        file scratchpad_file : text is scratchpad_filename;
        variable linenum     : integer := 0;
        variable line_buf: line;
        variable long_std_vec: std_logic_vector(63 downto 0);
    begin
        -- Load the program data
        linenum := 0;
        while not endfile(program_file) loop
            readline(program_file, line_buf);
            hread(line_buf, long_std_vec);
            ProgInstructions(linenum) <= long_std_vec;
            linenum := linenum + 1;
        end loop;
        -- Load the scratchpad data
        linenum := 0;
        while not endfile(scratchpad_file) loop
            readline(scratchpad_file, line_buf);
            hread(line_buf, long_std_vec);
            Scratchpad(linenum) <= long_std_vec;
            linenum := linenum + 1;
        end loop;
        wait for 100 ms;
        for linenum in ProgInstructions'range loop
            report to_hex(ProgInstructions(linenum));
        end loop;
        done <= TRUE;
        wait;
    end process;

end architecture;
