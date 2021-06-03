----------------------------------------------------------------------------
--! @file
--! @brief Floating Point ALU
--
--! Performs floating point ops on data inputs.
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

package float_pkg_rpinf is new ieee.float_generic_pkg
  generic map (
    float_exponent_width => 11,    -- float64'high
    float_fraction_width => 52,   -- -float64'low
    float_round_style    => ieee.fixed_float_types.round_inf,  -- round positive infinity
    float_denormalize    => true,  -- Use IEEE extended floating
    float_check_error    => true,  -- Turn on NAN and overflow processing
    float_guard_bits     => 3,     -- number of guard bits
    no_warning           => false, -- show warnings
    fixed_pkg            => ieee.fixed_pkg
    );

library ieee;

package float_pkg_rninf is new ieee.float_generic_pkg
  generic map (
    float_exponent_width => 11,    -- float64'high
    float_fraction_width => 52,   -- -float64'low
    float_round_style    => ieee.fixed_float_types.round_neginf,  -- round negative infinity
    float_denormalize    => true,  -- Use IEEE extended floating
    float_check_error    => true,  -- Turn on NAN and overflow processing
    float_guard_bits     => 3,     -- number of guard bits
    no_warning           => false, -- show warnings
    fixed_pkg            => ieee.fixed_pkg
    );

library ieee;

package float_pkg_rzero is new ieee.float_generic_pkg
  generic map (
    float_exponent_width => 11,    -- float64'high
    float_fraction_width => 52,   -- -float64'low
    float_round_style    => ieee.fixed_float_types.round_zero,  -- round zero
    float_denormalize    => true,  -- Use IEEE extended floating
    float_check_error    => true,  -- Turn on NAN and overflow processing
    float_guard_bits     => 3,     -- number of guard bits
    no_warning           => false, -- show warnings
    fixed_pkg            => ieee.fixed_pkg
    );

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.float_pkg_rnear;
use work.float_pkg_rpinf;
use work.float_pkg_rninf;
use work.float_pkg_rzero;

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
end;

architecture behavioral of FloatALU is
    signal computedResult : Common.FloatReg_t;
    signal computedTag : Common.optag_t;

    signal rnear_src_val_0 : float_pkg_rnear.float;
    signal rnear_src_val_1 : float_pkg_rnear.float;
    signal rnear_dst_val_0 : float_pkg_rnear.float;
    signal rnear_dst_val_1 : float_pkg_rnear.float;

    signal rnear_result_val_0 : float_pkg_rnear.float;
    signal rnear_result_val_1 : float_pkg_rnear.float;
begin

    computedTag <= inTag;
    StorageProc: process(clk)
    begin
        if rising_edge(clk) then
            outDst <= computedResult;
            outTag <= computedTag;
        end if; 
    end process StorageProc;

    RoundModeSelectProc: process(all)
    begin
        -- TODO(WHW): This process should be redone to
        -- select between different rounding modes
        computedResult.val_0 <= to_slv(rnear_result_val_0);
        computedResult.val_1 <= to_slv(rnear_result_val_1);
    end process RoundModeSelectProc;

    CalculateRNearProc: process(all)
        variable slv_temp : std_logic_vector(63 downto 0);
    begin
        rnear_result_val_0 <= (others => 'X');
        rnear_result_val_1 <= (others => 'X');
        case inInst is
            when FSWAP_R  =>
                -- (dst0, dst1) = (dst1, dst0)
                rnear_result_val_0 <= rnear_dst_val_1;
                rnear_result_val_1 <= rnear_dst_val_0;
            when FADD_R   =>
                -- (dst0, dst1) = (dst0 + src0, dst1 + src1)
                rnear_result_val_0 <= rnear_dst_val_0 + rnear_src_val_0;
                rnear_result_val_1 <= rnear_dst_val_1 + rnear_src_val_1;
            when FADD_M   =>
                -- (dst0, dst1) = (dst0 + [mem][0], dst1 + [mem][1])
                -- Same as FADD_R
                rnear_result_val_0 <= rnear_dst_val_0 + rnear_src_val_0;
                rnear_result_val_1 <= rnear_dst_val_1 + rnear_src_val_1;
            when FSUB_R   =>
                -- (dst0, dst1) = (dst0 - src0, dst1 - src1)
                rnear_result_val_0 <= rnear_dst_val_0 - rnear_src_val_0;
                rnear_result_val_1 <= rnear_dst_val_1 - rnear_src_val_1;
            when FSUB_M   =>
                -- (dst0, dst1) = (dst0 - src0, dst1 - src1)
                -- Same as FSUB_R
                rnear_result_val_0 <= rnear_dst_val_0 - rnear_src_val_0;
                rnear_result_val_1 <= rnear_dst_val_1 - rnear_src_val_1;
            when FSCAL_R  =>
                -- (dst0, dst1) = (-2 x0 * dst0, -2 x1 * dst1)
                -- See RandomX_specs.md though. This is a special XOR operation with 0x80F0000000000000.
                slv_temp := to_slv(rnear_dst_val_0);
                slv_temp(63 downto 48) := slv_temp(63 downto 48) xor 16#80F0#;
                rnear_result_val_0 <= to_float(slv_temp);
                slv_temp := to_slv(rnear_dst_val_1);
                slv_temp(63 downto 48) := slv_temp(63 downto 48) xor 16#80F0#;
                rnear_result_val_1 <= to_float(slv_temp);
            when FMUL_R   =>
                -- (dst0, dst1) = (dst0 * src0, dst1 * src1)
                rnear_result_val_0 <= rnear_dst_val_0 * rnear_src_val_0;
                rnear_result_val_1 <= rnear_dst_val_1 * rnear_src_val_1;
            when FDIV_R   =>
                -- (dst0, dst1) = (dst0 / [mem][0], dst1 / [mem][1])
                rnear_result_val_0 <= rnear_dst_val_0 / rnear_src_val_0;
                rnear_result_val_1 <= rnear_dst_val_1 / rnear_src_val_1;
            when FSQRT_R  => 
                -- (dst0, dst1) = (sqrt(dst0), sqrt(dst1))
                rnear_result_val_0 <= sqrt(rnear_dst_val_0);
                rnear_result_val_1 <= sqrt(rnear_dst_val_1);
            when others   =>
                computedResult.val_0 <= (others => 'X');
                computedResult.val_1 <= (others => 'X');
        end case;
    end process CalculateRNearProc;

end architecture;
