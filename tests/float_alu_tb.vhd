----------------------------------------
--! @file
--! @brief Testbench for the float alu
--! @brief This testbench is very simple, and is only used for probing issues
--! @brief Full functionality testing is done with loop_engine_tb
--! @author Will Werst
--! @date   May 2021
----------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.math_real.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

library osvvm;
use osvvm.CoveragePkg.all;
use osvvm.AlertLogPkg.all;
use osvvm.RandomPkg.all;

use work.Common;
use work.RdxCfg;

use work.float_pkg_rnear;


entity FloatALUTB is
end FloatALUTB;

architecture behavioral of FloatALUTB is

    component FloatALU
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
    end component;

    
    constant CLK_PERIOD : time := 1 ms;
    signal done : boolean := FALSE;
    
    -- Loop Engine signals
    signal clk    : std_logic := '0';
    signal reset  : std_logic := '0';
    signal floatALU_inDst  : Common.FloatReg_t;   
    signal floatALU_inSrc  : Common.FloatReg_t;   
    signal floatALU_inInst : Common.ReducedInst_t;
    signal floatALU_inTag  : Common.OpTag_t;      
    signal floatALU_outDst : Common.FloatReg_t;   
    signal floatALU_outTag : Common.OpTag_t;

    signal floatALU_inDst0_real : real;
    signal floatALU_inDst1_real : real;
    signal floatALU_inSrc0_real : real;
    signal floatALU_inSrc1_real : real;
    signal floatALU_outDst0_real : real;
    signal floatALU_outDst1_real : real;

    function to_hex(slv : std_logic_vector) return string is
        variable l : line;
    begin
        hwrite(l, slv);
        return l.all;
    end to_hex;

    -- For final testing, run at least 100_000 tests per op.
    constant NUM_TESTS_PER_OP : integer := 5000;

    constant TEST_BINS: CovBinType := (
        -- Arithmetic
        --GenBin(Common.RandX_Op_t'POS(  Common.FSWAP_R)) &
        GenBin(Common.RandX_Op_t'POS(   Common.FADD_R)) &
        GenBin(Common.RandX_Op_t'POS(   Common.FADD_M))
        --GenBin(Common.RandX_Op_t'POS(   Common.FSUB_R)) &
        --GenBin(Common.RandX_Op_t'POS(   Common.FSUB_M)) &
        --GenBin(Common.RandX_Op_t'POS(  Common.FSCAL_R)) &
        --GenBin(Common.RandX_Op_t'POS(   Common.FMUL_R)) &
        --GenBin(Common.RandX_Op_t'POS(   Common.FDIV_M)) &
        --GenBin(Common.RandX_Op_t'POS(  Common.FSQRT_R))
    );

    shared variable TestCov : CovPType;

begin

    UUT_FloatALU: FloatALU port map
        (
            clk    => clk   ,
            reset  => reset ,
            inDst  => floatALU_inDst ,
            inSrc  => floatALU_inSrc ,
            inInst => floatALU_inInst,
            inTag  => floatALU_inTag ,
            outDst => floatALU_outDst,
            outTag => floatALU_outTag
    );

    floatALU_inDst.val_0 <= float_pkg_rnear.to_slv(float_pkg_rnear.to_float(floatALU_inDst0_real));
    floatALU_inDst.val_1 <= float_pkg_rnear.to_slv(float_pkg_rnear.to_float(floatALU_inDst1_real));
    floatALU_inSrc.val_0 <= float_pkg_rnear.to_slv(float_pkg_rnear.to_float(floatALU_inSrc0_real));
    floatALU_inSrc.val_1 <= float_pkg_rnear.to_slv(float_pkg_rnear.to_float(floatALU_inSrc1_real));

    floatALU_outDst0_real <= float_pkg_rnear.to_real(float_pkg_rnear.to_float(floatALU_outDst.val_0));
    floatALU_outDst1_real <= float_pkg_rnear.to_real(float_pkg_rnear.to_float(floatALU_outDst.val_1));

    CLOCK_PROC: process begin
        while not done loop
            clk <= '0';
            wait for CLK_PERIOD/2;
            clk <= '1';
            wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process CLOCK_PROC;

    STIMULUS_PROC: process
        variable tv_OpCode : integer;
        variable tv_IntOpSrc : integer;
        variable tv_IntOpDst : integer;
        variable tv_reducedinst_t : Common.ReducedInst_t;
        variable RV        : RandomPType;
    begin
        SetAlertLogName("FloatAluTestbench");
        
        TestCov.AddBins(AtLeast => NUM_TESTS_PER_OP, CovBin => TEST_BINS);
        
        floatALU_inTag <= ('0', 0); -- Set input as not valid
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
            floatALU_inInst <= tv_reducedinst_t;
            floatALU_inSrc0_real <= RV.RandReal(1.0, 1000000.0);
            floatALU_inSrc1_real <= RV.RandReal(1.0, 1000000.0);
            floatALU_inDst0_real <= RV.RandReal(1.0, 1000000.0);
            floatALU_inDst1_real <= RV.RandReal(1.0, 1000000.0);
            floatALU_inTag <= ('1', 0); -- Set input as valid
            wait until rising_edge(clk);
            floatALU_inTag <= ('0', 0); -- Set input as invalid
            wait until rising_edge(clk);
            TestCov.ICover(tv_OpCode);
        end loop;
        TestCov.WriteBin;

        done <= TRUE;
        wait;
    end process;

    MONITOR_PROC: process
        variable monitor_tb_id : integer;
        variable insrc0  : real;
        variable insrc1  : real;
        variable indst0  : real;
        variable indst1  : real;
        variable outdst0 : real;
        variable outdst1 : real;
        variable expect_outdst0 : real;
        variable expect_outdst1 : real;
        variable inInst  : Common.ReducedInst_t;
    begin
        monitor_tb_id := GetAlertLogID("floatAluTestbench", ALERTLOG_BASE_ID);
        while not done loop
            wait until floatALU_inTag.valid = '0';
            wait until floatALU_inTag.valid = '1';
            insrc0 := floatALU_inSrc0_real;
            insrc1 := floatALU_inSrc1_real;
            indst0 := floatALU_inDst0_real;
            indst1 := floatALU_inDst1_real;
            inInst := floatALU_inInst;
            wait until floatALU_outTag.valid = '1';
            wait for 0 ns; -- Wait delta cycle for floatALU_outDst*_real to propagate.
            outdst0 := floatALU_outDst0_real;
            outdst1 := floatALU_outDst1_real;
            case inInst.opcode is
                when Common.FSWAP_R =>
                    -- (dst0, dst1) = (dst1, dst0)
                    expect_outdst0 := indst1;
                    expect_outdst1 := indst0;
                    AffirmIf(monitor_tb_id, abs(expect_outdst0 - outdst0) < 0.001, " FSWAP_R op incorrect");
                    AffirmIf(monitor_tb_id, abs(expect_outdst1 - outdst1) < 0.001, " FSWAP_R op incorrect");
                when Common.FADD_R =>
                    -- (dst0, dst1) = (dst0 + src0, dst1 + src1)
                    expect_outdst0 := indst0 + insrc0;
                    expect_outdst1 := indst1 + insrc1;
                    AffirmIf(monitor_tb_id, abs(expect_outdst0 - outdst0) < 0.001, " FADD_R op incorrect");
                    AffirmIf(monitor_tb_id, abs(expect_outdst1 - outdst1) < 0.001, " FADD_R op incorrect");
                when Common.FADD_M =>
                    -- (dst0, dst1) = (dst0 + [mem][0], dst1 + [mem][1])
                    expect_outdst0 := indst0 + insrc0;
                    expect_outdst1 := indst1 + insrc1;
                    AffirmIf(monitor_tb_id, abs(expect_outdst0 - outdst0) < 0.001, " FADD_M op incorrect");
                    AffirmIf(monitor_tb_id, abs(expect_outdst1 - outdst1) < 0.001, " FADD_M op incorrect");
                when others =>
                    AffirmIf(monitor_tb_id, FALSE, " Unexpected opcode sent ");
            end case;
        end loop;
        wait;
    end process;

end architecture;

