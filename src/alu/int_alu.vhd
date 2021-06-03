----------------------------------------------------------------------------
--! @file
--! @brief Integer ALU
--
--! Performs integer ops on data inputs.
--
----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Common;


-- Integer ALU
--
entity IntALU is

    port (
        clk         :  in     std_logic;                       -- system clock
        reset       :  in     std_logic;                       -- reset signal (active low)
        inDst       :  in     Common.IntReg_t;                 -- Integer operand A
        inSrc       :  in     Common.IntReg_t;                 -- Integer operand B
        inInst      :  in     Common.ReducedInst_t;            -- Operation to apply
        inTag       :  in     Common.OpTag_t;                  -- Operand tag (for Tomasulo)
        outDst      :  out    Common.intreg_t;
        outTag      :  out    Common.OpTag_t
    );

end IntALU;

architecture behavioral of IntALU is
    signal computedResult : Common.intreg_t;
    signal computedTag : Common.optag_t;

    signal unsignedDst : unsigned(63 downto 0);
    signal unsignedSrc : unsigned(63 downto 0);
    signal signedDst   : signed(63 downto 0);
    signal signedSrc   : signed(63 downto 0); 
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
    signedDst <= unsigned(inDst);
    signedSrc <= unsigned(inSrc);

    CalculateProc: process(all)
    begin
        computedResult <= (others => 'X');
        case inInst is
            when IADD_RS  =>
            when IADD_M   =>  
                -- dst = dst + [mem]
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
