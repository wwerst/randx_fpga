----------------------------------------------------------------------------
--! @file
--! @brief Floating Point ALU
--
--! Performs floating point ops on data inputs.
----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Common;


-- Integer ALU
--
entity FloatALU is

    port (
        clk         :  in     std_logic;                       -- system clock
        reset       :  in     std_logic;                       -- reset signal (active low)
        inDst       :  in     Common.FloatReg_t;                 -- Integer operand A
        inSrc       :  in     Common.FloatReg_t;                 -- Integer operand B
        inInst      :  in     Common.ReducedInst_t;            -- Operation to apply
        inTag       :  in     Common.OpTag_t;                  -- Operand tag (for Tomasulo)
        outDst      :  out    Common.FloatReg_t;
        outTag      :  out    Common.OpTag_t
    );

end FloatALU;

architecture behavioral of FloatALU is
    computedResult : Common.FloatReg_t;
    computedTag : Common.optag_t;
begin

    computedTag <= inTag;
    StorageProc: process(clk)
    begin
        if rising_edge(clk) then
            outDst <= computedResult;
            outTag <= computedTag;
        end if; 
    end process StorageProc;

    CalculateProc: process(all)
    begin
        computedResult.val_0 <= (others => 'X');
        computedResult.val_1 <= (others => 'X');
        case inInst is
            when FSWAP_R  =>  
            when FADD_R   =>
            when FADD_M   =>
            when FSUB_R   =>  
            when FSUB_M   =>  
            when FSCAL_R  =>  
            when FMUL_R   =>  
            when FDIV_R   =>  
            when FSQRT_R  => 
            when others   =>
                computedResult.val_0 <= (others => 'X');
                computedResult.val_1 <= (others => 'X');
        end case;
    end process CalculateProc;

end architecture;
