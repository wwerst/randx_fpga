---------------------------------------------------------------------
--
-- Common data to the RandomX CPU
--
---------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package Common is

    -- Constants
    constant SIZE_QWORD : natural := 64;
    constant SIZE_SPAD_ADDR : natural := 21 - 3; --! Scratchpad is 2097152 bytes, addressable by 8-byte.
 
    -- Number of registers by type. See 4.3 in RandomX_specs.pdf
    constant REG_R_NUM : natural := 8;
    constant REG_F_NUM : natural := 4;
    constant REG_E_NUM : natural := 4;
    constant REG_A_NUM : natural := 4;

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

    subtype SPadAddr_t is std_logic_vector(SIZE_SPAD_ADDR-1 downto 0); --! Scratchpad address bus
    subtype QWord_t is std_logic_vector(SIZE_QWORD-1 downto 0); --! Quad-word is 8 bytes

    subtype IntReg_t is std_logic_vector(SIZE_QWORD-1 downto 0);
    type FloatReg_t is record
        val_0 : std_logic_vector(SIZE_QWORD-1 downto 0);
        val_1 : std_logic_vector(SIZE_QWORD-1 downto 0);
    end record FloatReg_t;

    subtype RegRArr_t is array (0 to REG_R_NUM) of std_logic_vector(SIZE_QWORD-1 downto 0);
    subtype RegFArr_t is array (0 to REG_F_NUM) of std_logic_vector(SIZE_QWORD-1 downto 0);
    subtype RegFArr_t is array (0 to REG_F_NUM) of std_logic_vector(SIZE_QWORD-1 downto 0);
    subtype RegFArr_t is array (0 to REG_F_NUM) of std_logic_vector(SIZE_QWORD-1 downto 0);
    type RegTable_t is record
        r    : RegRArr_t;
        f    : RegFArr_t;
        e    : RegEArr_t;
        a    : RegAArr_t;
        fprc : std_logic_vector(1 downto 0);
    end record RegTable_t;


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
    type reduced_inst_t is record
        imm32       : signed(31 downto 0);
        mod_mem     : unsigned(1 downto 0);
        mod_shift   : unsigned(1 downto 0);
        mod_cond    : unsigned(3 downto 0);
        src         : unsigned(2 downto 0);
        dst         : unsigned(2 downto 0);
        opcode      : RandX_Op_t;
    end record;

    -- TODO(WHW): Currently dead code
    type optag_t is record
        valid       : std_logic;
        ident       : integer range 0 to 31;
    end record;

    -- TODO(WHW): Currently dead code
    subtype intreg_t is std_logic_vector(63 downto 0);

    -- Integer ALU Ops. These are derived from the full RandX_Op_t
    -- ops, but contain the results after eliminating memory deps and stuff.
    -- TODO(WHW): Currently dead code
    type IntOp_t is (
        IADDShift_Op,
        ISUB_Op,
        IMULL_Op, -- Lower 64 bits of unsigned multiply
        IMULH_Op, -- Upper 64 bits of unsigned multiply
        ISMULH_Op,
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

end package;

