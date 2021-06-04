----------------------------------------------------------------------------
--! @file
--! @brief Integer ALU
--! @brief Performs integer ops on data inputs.
--
--! @author Will Werst
--! @date   May/June 2021
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
    signedDst <= signed(inDst);
    signedSrc <= signed(inSrc);

    CalculateProc: process(all)
        variable tmp_signed : signed(Common.SIZE_QWORD-1 downto 0);
        variable res_signed : signed(Common.SIZE_QWORD-1 downto 0);
        variable res_unsigned : unsigned(Common.SIZE_QWORD-1 downto 0);
        variable tmp_slv128   : std_logic_vector(2*Common.SIZE_QWORD-1 downto 0);
        variable rotate_int   : integer range 0 to 63;
    begin
        computedResult <= (others => 'X');
        case inInst.opcode is
            when Common.IADD_RS  =>
                -- dst = dst + (src << mod.shift) (+ imm32)
                tmp_signed := (signedSrc sll to_integer(inInst.mod_shift));
                if inInst.dst = 5 then
                    -- Additional special condition for this instruction
                    -- in the RandomX documentation.
                    tmp_signed := tmp_signed + inInst.imm32;
                end if;
                res_signed := signedDst + tmp_signed;
                computedResult <= std_logic_vector(res_signed);
            when Common.IADD_M   =>  
                -- dst = dst + [mem]
                res_signed := signedDst + signedSrc;
                computedResult <= std_logic_vector(res_signed);
            when Common.ISUB_R   =>  
                -- dst = dst - src
                res_signed := signedDst - signedSrc;
                computedResult <= std_logic_vector(res_signed);
            when Common.ISUB_M   =>
                -- dst = dst - [mem]
                res_signed := signedDst - signedSrc;
                computedResult <= std_logic_vector(res_signed);
            when Common.IMUL_R   =>
                -- dst = dst * src
                tmp_slv128 := std_logic_vector(unsignedDst * unsignedSrc);
                computedResult <= tmp_slv128(Common.SIZE_QWORD-1 downto 0);
            when Common.IMUL_M   =>
                -- dst = dst * [mem]
                tmp_slv128 := std_logic_vector(unsignedDst * unsignedSrc);
                computedResult <= tmp_slv128(Common.SIZE_QWORD-1 downto 0);
            when Common.IMULH_R  =>
                -- dst = (dst * src) >> 64
                tmp_slv128 := std_logic_vector(unsignedDst * unsignedSrc);
                computedResult <= tmp_slv128(2*Common.SIZE_QWORD-1 downto Common.SIZE_QWORD);
            when Common.IMULH_M  =>
                -- dst = (dst * [mem]) >> 64
                tmp_slv128 := std_logic_vector(unsignedDst * unsignedSrc);
                computedResult <= tmp_slv128(2*Common.SIZE_QWORD-1 downto Common.SIZE_QWORD);
            when Common.ISMULH_R =>
                -- dst = (dst * src) >> 64 (signed)
                tmp_slv128 := std_logic_vector(signedDst * signedSrc);
                computedResult <= tmp_slv128(2*Common.SIZE_QWORD-1 downto Common.SIZE_QWORD);
            when Common.ISMULH_M =>
                -- dst = (dst * [mem]) >> 64 (signed)
                tmp_slv128 := std_logic_vector(signedDst * signedSrc);
                computedResult <= tmp_slv128(2*Common.SIZE_QWORD-1 downto Common.SIZE_QWORD);
            when Common.IMUL_RCP =>
                -- dst = rcp * dst
                -- where rcp = 2^x / imm32
                -- where x is largest integer such that rcp < 2^64
                -- This is implemented internally by using src to contain rcp,
                -- and rcp is calculated externally beforehand.
                tmp_slv128 := std_logic_vector(unsignedDst * unsignedSrc);
                computedResult <= tmp_slv128(Common.SIZE_QWORD-1 downto 0);
            when Common.INEG_R   =>
                -- dst = -dst
                res_signed := -signedDst;
                computedResult <= std_logic_vector(res_signed);
            when Common.IXOR_R   =>
                -- dst = dst ^ src
                computedResult <= inDst xor inSrc;
            when Common.IXOR_M   =>
                -- dst = dst ^ [mem]
                computedResult <= inDst xor inSrc;
            when Common.IROR_R   =>
                -- dst = dst >>> src
                rotate_int := to_integer(unsignedSrc(5 downto 0));
                computedResult <= inDst ror rotate_int;
            when Common.IROL_R   =>
                -- dst = dst <<< src
                rotate_int := to_integer(unsignedSrc(5 downto 0));
                computedResult <= inDst rol rotate_int;
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
