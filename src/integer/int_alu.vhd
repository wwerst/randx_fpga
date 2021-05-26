----------------------------------------------------------------------------
--! @file
--! @brief Integer ALU
--
--! Performs integer ops on data inputs.
--! Tags are propagated along with 
--
--
----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
--use ieee.std_logic_arith.all;
use ieee.numeric_std.all;

use work.Common;


-- Integer ALU
--
-- Implements 
--
entity int_alu is

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

end int_alu;

architecture behavioral of int_alu is
    computedResult : Common.intreg_t;
    computedTag : Common.optag_t;

    unsignedDst : unsigned(63 downto 0);
    unsignedSrc : unsigned(63 downto 0);
    signedDst   : signed(63 downto 0);
    signedSrc   : signed(63 downto 0); 
begin

    computedTag <= inTag;
    StorageProc: process(clk)
    begin
        if rising_edge(clk) then
            outDst <= computedResult;
            outTag <= computedTag;
        end if; 
    end process StorageProc;

    unsignedDst <= unsigned(inDst);
    unsignedSrc <= unsigned(inSrc);

    CalculateProc: process(all)
        variable unsignedResult : unsigned(63 downto 0);
    begin
        unsignedResult := (others => '0');
        case inOpCode is
        when IADD_RS  =>  
            -- dst = dst + (src << mod.shift) (+ imm32)
            unsignedResult := unsignedDst + (unsignedSrc sll inInst.mod_shift);
            if inInst.dst = 5 then
                unsignedResult := unsignedResult + inInst.imm32;
            end if;
            computedResult <= std_logic_vector(unsignedResult);
        when IADD_M   =>  
            -- dst = dst + [mem]
            unsignedResult := unsignedDst + unsignedSrc;
        when ISUB_R   =>  
            -- dst = dst - src
        when ISUB_M   =>  
        when IMUL_R   =>  
        when IMUL_M   =>  
        when IMULH_R  =>  
        when IMULH_M  =>  
        when ISMULH_R =>  
        when ISMULH_M =>  
        when IMUL_RCP =>  
        when INEG_R   =>  
        when IXOR_R   =>  
        when IXOR_M   =>  
        when IROR_R   =>  
        when IROL_R   =>  
        when others =>
            computedResult <= (others => 'X');
        end case;
    end process CalculateProc;

end architecture;
