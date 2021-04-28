

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


-- RegisterUnit
--
-- Implements a register unit for Tomasulo's Algorithm.
-- This means that entries have either the current value,
-- or 

entity RegisterUnit is

    port (
        Clk   : in std_logic;
        Reset : in std_logic;
    );
end RegisterUnit;

architecture dataflow of RegisterUnit is

begin

end dataflow;