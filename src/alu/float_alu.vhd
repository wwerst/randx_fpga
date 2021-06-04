----------------------------------------------------------------------------
--! @file
--! @brief Floating Point ALU
--
--! Performs floating point ops on data inputs.
--! @author Will Werst
--! @date   May/June 2021
----------------------------------------------------------------------------

library ieee;

package float_pkg_rnear is new ieee.float_generic_pkg
  generic map (
    float_exponent_width => 11,    -- float64'high
    float_fraction_width => 52,   -- -float64'low
    float_round_style    => ieee.fixed_float_types.round_nearest,  -- round nearest algorithm
    float_denormalize    => true,  -- Use IEEE extended floating
    float_check_error    => true,  -- Turn on NAN and overflow processing
    float_guard_bits     => 3,     -- number of guard bits
    no_warning           => false, -- show warnings
    fixed_pkg            => ieee.fixed_pkg
    );

library ieee;

-- HACK(WHW): Only support round nearest for now.

--package float_pkg_rpinf is new ieee.float_generic_pkg
--  generic map (
--    float_exponent_width => 11,    -- float64'high
--    float_fraction_width => 52,   -- -float64'low
--    float_round_style    => ieee.fixed_float_types.round_inf,  -- round positive infinity
--    float_denormalize    => true,  -- Use IEEE extended floating
--    float_check_error    => true,  -- Turn on NAN and overflow processing
--    float_guard_bits     => 3,     -- number of guard bits
--    no_warning           => false, -- show warnings
--    fixed_pkg            => ieee.fixed_pkg
--    );

--library ieee;

--package float_pkg_rninf is new ieee.float_generic_pkg
--  generic map (
--    float_exponent_width => 11,    -- float64'high
--    float_fraction_width => 52,   -- -float64'low
--    float_round_style    => ieee.fixed_float_types.round_neginf,  -- round negative infinity
--    float_denormalize    => true,  -- Use IEEE extended floating
--    float_check_error    => true,  -- Turn on NAN and overflow processing
--    float_guard_bits     => 3,     -- number of guard bits
--    no_warning           => false, -- show warnings
--    fixed_pkg            => ieee.fixed_pkg
--    );

--library ieee;

--package float_pkg_rzero is new ieee.float_generic_pkg
--  generic map (
--    float_exponent_width => 11,    -- float64'high
--    float_fraction_width => 52,   -- -float64'low
--    float_round_style    => ieee.fixed_float_types.round_zero,  -- round zero
--    float_denormalize    => true,  -- Use IEEE extended floating
--    float_check_error    => true,  -- Turn on NAN and overflow processing
--    float_guard_bits     => 3,     -- number of guard bits
--    no_warning           => false, -- show warnings
--    fixed_pkg            => ieee.fixed_pkg
--    );

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.float_pkg_rnear.all;

use work.Common;


-- Float ALU
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
end;

architecture behavioral of FloatALU is
    signal computedResult : Common.FloatReg_t;
    signal computedTag : Common.optag_t;

    signal rnear_src_val_0 : float64;
    signal rnear_src_val_1 : float64;
    signal rnear_dst_val_0 : float64;
    signal rnear_dst_val_1 : float64;

    signal rnear_result_val_0 : float64;
    signal rnear_result_val_1 : float64;
begin

    computedTag <= inTag;
    StorageProc: process(clk)
    begin
        if rising_edge(clk) then
            outDst <= computedResult;
            outTag <= computedTag;
        end if; 
    end process StorageProc;

    -- TODO(WHW): Right now, this only supports round nearest.
    -- In the future, add support here to mux to select rounding mode.
    RoundModeSelectProc: process(all)
    begin
        -- TODO(WHW): This process should be redone to
        -- select between different rounding modes
        computedResult.val_0 <= to_slv(rnear_result_val_0);
        computedResult.val_1 <= to_slv(rnear_result_val_1);
    end process RoundModeSelectProc;

    -- Convert the input values into floats
    rnear_src_val_0 <= to_float(inSrc.val_0);
    rnear_src_val_1 <= to_float(inSrc.val_1);
    rnear_dst_val_0 <= to_float(inDst.val_0);
    rnear_dst_val_1 <= to_float(inDst.val_1);

    -- Calcuate the values for different opcodes
    CalculateRNearProc: process(all)
        variable slv_temp : std_logic_vector(63 downto 0);
    begin
        rnear_result_val_0 <= (others => 'X');
        rnear_result_val_1 <= (others => 'X');
        case inInst.opcode is
            when Common.FSWAP_R  =>
                -- (dst0, dst1) = (dst1, dst0)
                rnear_result_val_0 <= rnear_dst_val_1;
                rnear_result_val_1 <= rnear_dst_val_0;
            when Common.FADD_R   =>
                -- (dst0, dst1) = (dst0 + src0, dst1 + src1)
                rnear_result_val_0 <= add(rnear_dst_val_0, rnear_src_val_0);
                rnear_result_val_1 <= add(rnear_dst_val_1, rnear_src_val_1);
            when Common.FADD_M   =>
                -- (dst0, dst1) = (dst0 + [mem][0], dst1 + [mem][1])
                -- Same as FADD_R
                rnear_result_val_0 <= add(rnear_dst_val_0, rnear_src_val_0);
                rnear_result_val_1 <= add(rnear_dst_val_1, rnear_src_val_1);
            when Common.FSUB_R   =>
                -- (dst0, dst1) = (dst0 - src0, dst1 - src1)
                rnear_result_val_0 <= subtract(rnear_dst_val_0, rnear_src_val_0);
                rnear_result_val_1 <= subtract(rnear_dst_val_1, rnear_src_val_1);
            when Common.FSUB_M   =>
                -- (dst0, dst1) = (dst0 - src0, dst1 - src1)
                -- Same as FSUB_R
                rnear_result_val_0 <= subtract(rnear_dst_val_0, rnear_src_val_0);
                rnear_result_val_1 <= subtract(rnear_dst_val_1, rnear_src_val_1);
            when Common.FSCAL_R  =>
                -- (dst0, dst1) = (-2 x0 * dst0, -2 x1 * dst1)
                -- See RandomX_specs.md though. This is a special XOR operation with 0x80F0000000000000.
                slv_temp := to_slv(rnear_dst_val_0);
                slv_temp(63 downto 52) := slv_temp(63 downto 52) xor "100000001111";
                rnear_result_val_0 <= to_float(slv_temp);
                slv_temp := to_slv(rnear_dst_val_1);
                slv_temp(63 downto 52) := slv_temp(63 downto 52) xor "100000001111";
                rnear_result_val_1 <= to_float(slv_temp);
            when Common.FMUL_R   =>
                -- (dst0, dst1) = (dst0 * src0, dst1 * src1)
                rnear_result_val_0 <= rnear_dst_val_0 * rnear_src_val_0;
                rnear_result_val_1 <= rnear_dst_val_1 * rnear_src_val_1;
            when Common.FDIV_M   =>
                -- (dst0, dst1) = (dst0 / [mem][0], dst1 / [mem][1])
                rnear_result_val_0 <= rnear_dst_val_0 / rnear_src_val_0;
                rnear_result_val_1 <= rnear_dst_val_1 / rnear_src_val_1;
            when Common.FSQRT_R  => 
                -- (dst0, dst1) = (sqrt(dst0), sqrt(dst1))
                rnear_result_val_0 <= sqrt(rnear_dst_val_0);
                rnear_result_val_1 <= sqrt(rnear_dst_val_1);
            when others   =>
                rnear_result_val_0 <= (others => 'X');
                rnear_result_val_1 <= (others => 'X');
        end case;
    end process CalculateRNearProc;

end architecture;
