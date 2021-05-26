----------------------------------------------------------------------------
--! @file
--! @brief Top-Level RandomX CPU implementation
--
----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Common;


entity  CPU  is

    port (
        Clk         :  in     std_logic;                       -- system clock
        Reset       :  in     std_logic;                       -- reset signal (active low)
        Prog        :  in     RandomX_Common.raw_prog_arr_t;   -- Raw program
        SPadDB_Rd   :  in     std_logic_vector(63 downto 0);   -- scratchpad data bus
        SPadAB      :  out    std_logic_vector(18 downto 0);   -- scratchpad address bus
        SPadDB_Wr   :  out    std_logic_vector(63 downto 0)    -- scratchpad data bus
    );

end  CPU;

architecture dataflow of CPU is
    component RegisterUnit is
        port (
            Clk   : in std_logic;
            Reset : in std_logic
        );
    end component;
begin

end architecture;
