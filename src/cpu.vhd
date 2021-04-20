----------------------------------------------------------------------------
--
--  Atmel AVR CPU
--
--  This is the implementation of the complete AVR CPU.
--
--  Revision History:
--     11 May 98  Glen George       Initial revision.
--      9 May 00  Glen George       Updated comments.
--      7 May 02  Glen George       Updated comments.
--     21 Jan 08  Glen George       Updated comments.
--     22 Feb 21  Eric Chen         Start sketching implementation
--     27 Mar 21  Will Werst        Implement full cpu. See git
--                                  history for more granular details
--                                  and revision history.
--     27 Mar 21  Will Werst        Pipeline cpu.
----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
--use ieee.std_logic_arith.all;
use ieee.numeric_std.all;

use work.opcodes;
use work.AVR;
use work.IAU;
use work.DAU;
use work.ALUOp;

entity  AVR_CPU  is

    port (
        ProgDB  :  in     std_logic_vector(15 downto 0);   -- program memory data bus
        Reset   :  in     std_logic;                       -- reset signal (active low)
        INT0    :  in     std_logic;                       -- interrupt signal (active low)
        INT1    :  in     std_logic;                       -- interrupt signal (active low)
        clock   :  in     std_logic;                       -- system clock
        ProgAB  :  out    std_logic_vector(15 downto 0);   -- program memory address bus
        DataAB  :  out    std_logic_vector(15 downto 0);   -- data memory address bus
        DataWr  :  out    std_logic;                       -- data memory write enable (active low)
        DataRd  :  out    std_logic;                       -- data memory read enable (active low)
        DataDB  :  inout  std_logic_vector(7 downto 0)     -- data memory data bus
    );

end  AVR_CPU;

architecture dataflow of AVR_CPU is

end architecture;
