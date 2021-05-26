----------------------------------------------------------------------------
--! @file
--! @brief Floating Point ALU
--
--
----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Common;


-- Integer ALU
--
-- Implements 
--
entity float_alu is

    port (
        clk         :  in     std_logic;                       -- system clock
        reset       :  in     std_logic;                       -- reset signal (active low)
        inDst       :  in     Common.intreg_t;                 -- Integer operand A
        inSrc       :  in     Common.intreg_t;                 -- Integer operand B
        inInst      :  in     Common.reduce_inst_t;            -- Operation to apply
        inTag       :  in     Common.optag_t;                  -- Operand tag (for Tomasulo)
        outDst      :  out    Common.intreg_t;
        outTag      :  out    Common.optag_t
    );

end float_alu;

architecture behavioral of float_alu is
begin

end architecture;
