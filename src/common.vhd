---------------------------------------------------------------------
--
-- Common data to the RandomX CPU
--
---------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package Common is

    -- Enum of all of the opcodes
    type RandX_Op_t is (
        IADD_RS,
        IADD_M,
        ISUB_R,
        ISUB_M,
        IMUL_R,
        IMUL_M,
        IMULH_R,
        IMULH_M,
        ISMULH_R,
        ISMULH_M,
        IMUL_RCP,
        INEG_R,
        IXOR_R,
        IXOR_M,
        IROR_R,
        IROL_R,
        ISWAP_R,
        FSWAP_R,
        FADD_R
        FADD_M,
        FSUB_R,
        FSUB_M,
        FSCAL_R,
        FMUL_R,
        FDIV_M,
        FSQRT_R,
        CBRANCH,
        CFROUND,
        ISTORE,
        NOP,
    );

    -- 8-Byte raw instruction from RandomX instruction encoding
    type raw_inst_t is record
        imm32   : std_logic_vector(31 downto 0);
        mod_    : std_logic_vector(7 downto 0);
        src     : std_logic_vector(7 downto 0);
        dst     : std_logic_vector(7 downto 0);
        opcode  : std_logic_vector(7 downto 0);
    end record raw_inst_t;

    -- Reduced, or compressed, representation of RandomX instruction. It
    -- removes unused bits and
    type reduce_inst_t is record
        imm32       : signed(31 downto 0);
        mod_mem     : unsigned(1 downto 0);
        mod_shift   : unsigned(1 downto 0);
        mod_cond    : unsigned(3 downto 0);
        src         : unsigned(2 downto 0);
        dst         : unsigned(2 downto 0);
        opcode      : RandX_Op_t;
    end record;

    type raw_prog_arr_t is array (0 to 255) of raw_inst_t;


end package;

