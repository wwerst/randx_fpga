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
        inInst      :  in     Common.ReducedInst_t;               -- Operation to apply
        inTag       :  in     Common.OpTag_t;                  -- Operand tag (for Tomasulo)
        outDst      :  out    Common.IntReg_t;
        outTag      :  out    Common.OpTag_t
    );

end IntALU;

architecture behavioral of IntALU is
    signal computedResult : Common.IntReg_t;
    signal computedTag    : Common.optag_t;

    signal unsignedDst : unsigned(63 downto 0);
    signal unsignedSrc : unsigned(63 downto 0);
    signal signedDst   : signed(63 downto 0);
    signal signedSrc   : signed(63 downto 0); 
begin

    computedTag <= inTag;

    -- Store the result to the output
    StorageProc: process(clk)
    begin
        if rising_edge(clk) then
            outDst <= computedResult;
            outTag <= computedTag;
        end if; 
    end process StorageProc;

    -- Convert the input into unsigned and signed numbers
    unsignedDst <= unsigned(inDst);
    unsignedSrc <= unsigned(inSrc);
    signedDst <= unsigned(inDst);
    signedSrc <= unsigned(inSrc);

    CalculateProc: process(all)
        variable tmp_unsigned : unsigned(Common.SIZE_QWORD-1 downto 0);
    begin
        computedResult <= (others => 'X');
        case inInst is
            when Common.IADD_RS  =>
                -- dst = dst + (src << mod.shift) (+ imm32)
                tmp_unsigned := (unsignedSrc sll inInst.mod_shift);
                if inInst.dst = 5 then
                    -- Additional special condition for this instruction
                    -- in the RandomX documentation.
                    tmp_unsigned := tmp_unsigned + inInst.imm32;
                end if;
                computedResult <= unsignedDst + tmp_unsigned;
            when Common.IADD_M   =>  
                -- dst = dst + [mem]
                computedResult <= unsignedDst + unsignedSrc;
            when Common.ISUB_R   =>  
                -- dst = dst - src
                computedResult <= unsignedDst - unsignedSrc;
            when Common.ISUB_M   =>
                -- dst = dst - [mem]
                computedResult <= unsignedDst - unsignedSrc;
            when Common.IMUL_R   =>
                -- dst = dst * src
                computedResult <= (unsignedDst * unsignedSrc)(Common.SIZE_QWORD-1 downto 0);
            when Common.IMUL_M   =>
                -- dst = dst * [mem]
                computedResult <= (unsignedDst * unsignedSrc)(Common.SIZE_QWORD-1 downto 0);
            when Common.IMULH_R  =>
                -- dst = (dst * src) >> 64
                computedResult <= (unsignedDst * unsignedSrc)(2*Common.SIZE_QWORD-1 downto Common.SIZE_QWORD);
            when Common.IMULH_M  =>
                -- dst = (dst * [mem]) >> 64
                computedResult <= (unsignedDst * unsignedSrc)(2*Common.SIZE_QWORD-1 downto Common.SIZE_QWORD);
            when Common.ISMULH_R =>
                -- dst = (dst * src) >> 64 (signed)
                computedResult <= (signedDst * signedSrc)(2*Common.SIZE_QWORD-1 downto Common.SIZE_QWORD);
            when Common.ISMULH_M =>
                -- dst = (dst * [mem]) >> 64 (signed)
                computedResult <= (signedDst * signedSrc)(2*Common.SIZE_QWORD-1 downto Common.SIZE_QWORD);
            when Common.IMUL_RCP =>
                -- dst = rcp * dst
                -- where rcp = 2^x / imm32
                -- where x is largest integer such that rcp < 2^64
                -- This is implemented internally by using src to contain rcp,
                -- and rcp is calculated externally beforehand.
                computedResult <= (unsignedDst * unsignedSrc)(Common.SIZE_QWORD-1 downto 0);
            when Common.INEG_R   =>
                -- dst = -dst
                computedResult <= -signedDst;
            when Common.IXOR_R   =>
                -- dst = dst ^ src
                computedResult <= inDst xor inSrc;
            when Common.IXOR_M   =>
                -- dst = dst ^ [mem]
                computedResult <= inDst xor inSrc;
            when Common.IROR_R   =>
                -- dst = dst >>> src
                computedResult <= inDst ror inSrc;
            when Common.IROL_R   =>
                -- dst = dst <<< src
                computedResult <= inDst rol inSrc;
            when Common.ISWAP_R  =>
                -- temp = src; src = dst; dst = temp
                -- The int alu only has one output. This needs to
                -- be handled externally. To aid this, this just maps the
                -- inSrc to the output.
                computedResult <= inSrc;
            when others =>
                computedResult <= (others => 'X');
        end case;
    end process CalculateProc;

end architecture;
