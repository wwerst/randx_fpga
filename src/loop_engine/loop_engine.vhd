----------------------------------------
--! @file
--! @brief Execute the 256 instruction program as defined in
--! @brief 4.6.2 in RandomX_specs.pdf
--! @author Will Werst
--! @date   May 2021
----------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Common;

--! Executes the given 256 RandomX instructions when commanded.

--! The reg_table_in is used as the initial register file. Interfaces for the
--! external scratchpad and program memory are connected, and when start_prog
--! goes from '0' to '1' at clk, the program runs. When 'prog_done' is 
entity LoopEngine is

    generic (
        num_instructions : numeric := 256
    );
    port (
        clk   : in std_logic; --! Clock signal
        reset : in std_logic; --! Active-high reset
        reg_table_in : in Common.RegTable_t; --! Initial register table
        start_prog   : in std_logic;         --! On rising edge, this triggers program execution.
        prog_done    : out std_logic;        --! 0 when a program is running, and 1 when program is done or not running.
        reg_table_out : out Common.RegTable_t --! Final register table after program execution.
        );
end LoopEngine;

architecture behavioral of LoopEngine is



end architecture behavioral;
