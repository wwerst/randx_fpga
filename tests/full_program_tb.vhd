----------------------------------------------------------------------------
--
-- Integer ALU
--
-- Performs integer ops on data inputs.
-- Tags are propagated along with 
--
--
----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;


entity full_program_tb is
    generic (
        program_file    : string;
        scratchpad_file : string
    );
end full_program_tb;


architecture testbench of full_program_tb is

    constant CLK_PERIOD : time := 1 ms;
    signal done : boolean := FALSE;
    signal clk : std_logic := '0';
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
    begin
        wait for 100 ms;
        report program_file;
        report scratchpad_file; 
        done <= TRUE;
        wait;
    end process;

end architecture;
