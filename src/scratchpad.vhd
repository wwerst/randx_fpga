----------------------------------------------------------------------------
--
-- Scratchpad implementation
--
--
----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.RandomX_Common;

entity Scratchpad is

	port (
		Clk		: in    std_logic;
		Reset   : in    std_logic;
		SPadDB_Rd   :  in     std_logic_vector(63 downto 0);   -- scratchpad data bus
        SPadAB      :  out    std_logic_vector(18 downto 0);   -- scratchpad address bus
        SPadDB_Wr   :  out    std_logic_vector(63 downto 0)    -- scratchpad data bus
	);
end Scratchpad;

architecture dataflow of Scratchpad is

end architecture;