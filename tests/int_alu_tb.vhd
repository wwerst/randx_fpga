----------------------------------------
--! @file
--! @brief Testbench for the integer alu
--! @author Will Werst
--! @date   June 2021
----------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

library osvvm;
use osvvm.CoveragePkg.all;
use osvvm.AlertLogPkg.all;
use osvvm.RandomPkg.all;

use work.Common;
use work.RdxCfg;


entity IntALUTB is
end IntALUTB;

architecture behavioral of IntALUTB is

    component IntALU
        port (
            clk         :  in     std_logic;                       -- system clock
            reset       :  in     std_logic;                       -- reset signal (active low)
            inDst       :  in     Common.IntReg_t;                 -- Integer operand A
            inSrc       :  in     Common.IntReg_t;                 -- Integer operand B
            inInst      :  in     Common.ReducedInst_t;            -- Operation to apply
            inTag       :  in     Common.OpTag_t;                  -- Operand tag (for Tomasulo)
            outDst      :  out    Common.IntReg_t;
            outTag      :  out    Common.OpTag_t
        );
    end component;

    
    constant CLK_PERIOD : time := 1 ms;
    signal done : boolean := FALSE;
    
    -- UUT signals
    signal clk    : std_logic := '0';
    signal reset  : std_logic := '0';
    signal intALU_inDst  :  Common.IntReg_t;
    signal intALU_inSrc  :  Common.IntReg_t;
    signal intALU_inInst :  Common.ReducedInst_t;
    signal intALU_inTag  :  Common.OpTag_t;
    signal intALU_outDst :  Common.IntReg_t;
    signal intALU_outTag :  Common.OpTag_t;


    function to_hex(slv : std_logic_vector) return string is
        variable l : line;
    begin
        hwrite(l, slv);
        return l.all;
    end to_hex;

    -- For final testing, run at least 100_000 tests per op.
    constant NUM_TESTS_PER_OP : integer := 5000;

    constant randomWordBin: CovBinType := GenBin(AtLeast => NUM_TESTS_PER_OP, Min => 0, Max => 2**31 - 1, NumBin => 1);

    constant TEST_BINS: CovBinType := (
        -- Arithmetic
        GenBin(Common.RandX_Op_t'POS(  Common.IADD_RS)) & --  randomWordBin, randomWordBin) &
        GenBin(Common.RandX_Op_t'POS(   Common.IADD_M)) & --  randomWordBin, randomWordBin) &
        GenBin(Common.RandX_Op_t'POS(   Common.ISUB_R)) & -- randomWordBin, randomWordBin) &
        GenBin(Common.RandX_Op_t'POS(   Common.ISUB_M)) & -- randomWordBin, randomWordBin) &
        GenBin(Common.RandX_Op_t'POS(   Common.IMUL_R)) & -- randomWordBin, randomWordBin) &
        GenBin(Common.RandX_Op_t'POS(   Common.IMUL_M)) & -- randomWordBin, randomWordBin) &
        GenBin(Common.RandX_Op_t'POS(  Common.IMULH_R)) & -- randomWordBin, randomWordBin) &
        GenBin(Common.RandX_Op_t'POS(  Common.IMULH_M)) & -- randomWordBin, randomWordBin) &
        GenBin(Common.RandX_Op_t'POS( Common.ISMULH_R)) & --  randomWordBin, randomWordBin) &
        GenBin(Common.RandX_Op_t'POS( Common.ISMULH_M)) & --  randomWordBin, randomWordBin) &
        GenBin(Common.RandX_Op_t'POS( Common.IMUL_RCP)) & --  randomWordBin, randomWordBin) &
        GenBin(Common.RandX_Op_t'POS(   Common.INEG_R)) & -- randomWordBin, randomWordBin) &
        GenBin(Common.RandX_Op_t'POS(   Common.IXOR_R)) & -- randomWordBin, randomWordBin) &
        GenBin(Common.RandX_Op_t'POS(   Common.IXOR_M)) & -- randomWordBin, randomWordBin) &
        GenBin(Common.RandX_Op_t'POS(   Common.IROR_R)) & -- randomWordBin, randomWordBin) &
        GenBin(Common.RandX_Op_t'POS(   Common.IROL_R)) & -- randomWordBin, randomWordBin) &
        GenBin(Common.RandX_Op_t'POS(  Common.ISWAP_R))  -- randomWordBin, randomWordBin)
    );

    shared variable TestCov : CovPType;

begin

    -- Setup the integer ALU for testing
    UUT_IntALU: IntALU port map
        (
            clk         => clk,
            reset       => reset,
            inDst       => intALU_inDst,  
            inSrc       => intALU_inSrc,  
            inInst      => intALU_inInst,  
            inTag       => intALU_inTag,  
            outDst      => intALU_outDst,  
            outTag      => intALU_outTag  
    );

    CLOCK_PROC: process begin
        while not done loop
            clk <= '0';
            
            wait for CLK_PERIOD/2;
            clk <= '1';
            wait for CLK_PERIOD/2;
        end loop;
        report "Clock Process Terminating";
        wait;
    end process CLOCK_PROC;

    STIMULUS_PROC: process
        variable tv_OpCode : integer;
        variable tv_IntOpSrc : integer;
        variable tv_IntOpDst : integer;
        variable tv_reducedinst_t : Common.ReducedInst_t;
        variable RV        : RandomPType;
    begin
        SetAlertLogName("IntAluTestbench");
        
        TestCov.AddBins(AtLeast => NUM_TESTS_PER_OP, CovBin => TEST_BINS);
        
        intALU_inTag <= ('0', 0); -- Set input as not valid
        wait until rising_edge(clk);
        
        while not TestCov.IsCovered loop

            -- Sample opcode
            tv_OpCode := TestCov.GetRandPoint;
            tv_reducedinst_t := (
                imm32       =>  (others => '0'),
                mod_mem     =>  (others => '0'),
                mod_shift   =>  (others => '0'),
                mod_cond    =>  (others => '0'),
                src         =>  (others => '0'),
                dst         =>  (others => '0'),
                opcode      =>  Common.RandX_Op_t'VAL(tv_OpCode)
                );
            intALU_inInst <= tv_reducedinst_t;
            intALU_inDst <= RV.RandSlv(Size => 64);
            intALU_inSrc <= RV.RandSlv(Size => 64);
            intALU_inTag <= ('1', 0); -- Set input as valid
            wait until rising_edge(clk);
            intALU_inTag <= ('0', 0); -- Set input as invalid
            wait until rising_edge(clk);
            TestCov.ICover(tv_OpCode);
        end loop;
        TestCov.WriteBin;

        done <= TRUE;
        wait;
    end process;

    MONITOR_PROC: process
        variable monitor_tb_id : integer;
        variable unsigned_insrc  : unsigned(63 downto 0);
        variable unsigned_indst  : unsigned(63 downto 0);
        variable unsigned_outdst : unsigned(63 downto 0);
        variable expect_unsigned : unsigned(63 downto 0);
        variable expect_unsigned_128 : unsigned(127 downto 0);
        variable signed_insrc  : signed(63 downto 0);
        variable signed_indst  : signed(63 downto 0);
        variable signed_outdst : signed(63 downto 0);
        variable expect_signed : signed(63 downto 0);
        variable expect_signed_128 : signed(127 downto 0);
        variable rotate_int    : integer;
    begin
        monitor_tb_id := GetAlertLogID("IntAluTestbench", ALERTLOG_BASE_ID);
        while not done loop
            wait until intALU_inTag.valid = '0';
            wait until intALU_inTag.valid = '1';
            unsigned_insrc := unsigned(intALU_inSrc);
            unsigned_indst := unsigned(intALU_inDst);
            signed_insrc := signed(intALU_inSrc);
            signed_indst := signed(intALU_inDst);
            wait until intALU_outTag.valid = '1';
            unsigned_outdst := unsigned(intALU_outDst);
            signed_outdst := signed(intALU_outDst);
            case intALU_inInst.opcode is
                when Common.IADD_RS =>
                    rotate_int := to_integer(intALU_inInst.mod_shift);
                    expect_signed := (signed_indst + signed_insrc sll rotate_int);
                    if intALU_inInst.dst = 5 then
                        -- Special behavior for r5 that is specified in RandomX_Specs.pdf
                        expect_signed := expect_signed + intALU_inInst.imm32;
                    end if;
                    AffirmIf(monitor_tb_id, signed_outdst = expect_signed, " IADD_M op incorrect");
                when Common.IADD_M =>
                    expect_unsigned := (unsigned_indst + unsigned_insrc);
                    AffirmIf(monitor_tb_id, unsigned_outdst = expect_unsigned, " IADD_M op incorrect");
                when Common.ISUB_R =>
                    expect_unsigned := (unsigned_indst - unsigned_insrc);
                    AffirmIf(monitor_tb_id, unsigned_outdst = expect_unsigned, " ISUB_R op incorrect");
                when Common.ISUB_M =>
                    expect_unsigned := (unsigned_indst - unsigned_insrc);
                    AffirmIf(monitor_tb_id, unsigned_outdst = expect_unsigned, " ISUB_M op incorrect");
                when Common.IMUL_R =>
                    expect_unsigned_128 := (unsigned_indst * unsigned_insrc);
                    expect_unsigned := expect_unsigned_128(63 downto 0);
                    AffirmIf(monitor_tb_id, unsigned_outdst = expect_unsigned, " IMUL_R op incorrect");
                when Common.IMUL_M =>
                    expect_unsigned_128 := (unsigned_indst * unsigned_insrc);
                    expect_unsigned := expect_unsigned_128(63 downto 0);
                    AffirmIf(monitor_tb_id, unsigned_outdst = expect_unsigned, " IMUL_M op incorrect");
                when Common.IMULH_R =>
                    expect_unsigned_128 := (unsigned_indst * unsigned_insrc);
                    expect_unsigned := expect_unsigned_128(127 downto 64);
                    AffirmIf(monitor_tb_id, unsigned_outdst = expect_unsigned, " IMULH_R op incorrect");
                when Common.IMULH_M =>
                    expect_unsigned_128 := (unsigned_indst * unsigned_insrc);
                    expect_unsigned := expect_unsigned_128(127 downto 64);
                    AffirmIf(monitor_tb_id, unsigned_outdst = expect_unsigned, " IMULH_M op incorrect");
                when Common.ISMULH_R =>
                    expect_signed_128 := (signed_indst * signed_insrc);
                    expect_signed := expect_signed_128(127 downto 64);
                    AffirmIf(monitor_tb_id, signed_outdst = expect_signed, " ISMULH_R op incorrect");
                when Common.ISMULH_M =>
                    expect_signed_128 := (signed_indst * signed_insrc);
                    expect_signed := expect_signed_128(127 downto 64);
                    AffirmIf(monitor_tb_id, signed_outdst = expect_signed, " ISMULH_M op incorrect");
                when Common.IMUL_RCP =>
                    -- This operation does a reciprocal op, but the reciprocal is pre-computed and passed in via src
                    -- In the loop_engine. Thus, this is just unsigneddst * unsignedsrc
                    expect_unsigned_128 := (unsigned_indst * unsigned_insrc);
                    expect_unsigned := expect_unsigned_128(63 downto 0);
                    AffirmIf(monitor_tb_id, unsigned_outdst = expect_unsigned, " IMUL_RCP op incorrect");
                when Common.INEG_R =>
                    expect_signed := -signed_indst;
                    AffirmIf(monitor_tb_id, signed_outdst = expect_signed, " INEG_R op incorrect");
                when Common.IXOR_R =>
                    expect_unsigned := unsigned_indst xor unsigned_insrc;
                    AffirmIf(monitor_tb_id, unsigned_outdst = expect_unsigned, " IXOR_R op incorrect");
                when Common.IXOR_M =>
                    expect_unsigned := unsigned_indst xor unsigned_insrc;
                    AffirmIf(monitor_tb_id, unsigned_outdst = expect_unsigned, " IXOR_M op incorrect");
                when Common.IROR_R =>
                    rotate_int := to_integer(unsigned_insrc(10 downto 0));
                    expect_unsigned := unsigned(std_logic_vector(unsigned_indst) ror rotate_int);
                    AffirmIf(monitor_tb_id, unsigned_outdst = expect_unsigned, " IROR_R op incorrect");
                when Common.IROL_R =>
                    rotate_int := to_integer(unsigned_insrc(10 downto 0));
                    expect_unsigned := unsigned(std_logic_vector(unsigned_indst) rol rotate_int);
                    AffirmIf(monitor_tb_id, unsigned_outdst = expect_unsigned, " IROL_R op incorrect");
                when Common.ISWAP_R =>
                    -- The rest of the swap is done in the loop_engine.
                    -- Expected behavior here is for outdst = insrc
                    expect_unsigned := unsigned_insrc;
                    AffirmIf(monitor_tb_id, unsigned_outdst = expect_unsigned, " ISWAP_R op incorrect");
                when others =>
                    AffirmIf(monitor_tb_id, FALSE, " Unexpected opcode sent ");
            end case;
        end loop;
        wait;
    end process;

end architecture;

