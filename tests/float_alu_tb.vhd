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
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

library osvvm;
use osvvm.AlertLogPkg.all;

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
            inInst      :  in     Common.RandX_Op_t;            -- Operation to apply
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
    signal inDst  : Common.FloatReg_t;   
    signal inSrc  : Common.FloatReg_t;   
    signal inInst : Common.RandX_Op_t;
    signal inTag  : Common.OpTag_t;      
    signal outDst : Common.FloatReg_t;   
    signal outTag : Common.OpTag_t;

    function to_hex(slv : std_logic_vector) return string is
        variable l : line;
    begin
        hwrite(l, slv);
        return l.all;
    end to_hex;

begin

    UUT: FloatALU port map
        (
            clk    => clk   ,
            reset  => reset ,
            inDst  => inDst ,
            inSrc  => inSrc ,
            inInst => inInst,
            inTag  => inTag ,
            outDst => outDst,
            outTag => outTag
    );

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
        variable tmp_float : float_pkg_rnear.float64;
    begin
        wait until rising_edge(clk);
        tmp_float := float_pkg_rnear.to_float(6.25);
        inDst.val_0 <= float_pkg_rnear.to_slv(tmp_float);
        tmp_float := float_pkg_rnear.to_float(12.25);
        inDst.val_1 <= float_pkg_rnear.to_slv(tmp_float);
        --tmp_float := 3.0;
        --inSrc.val_0 <= to_slv(tmp_float);
        --tmp_float := 5.0;
        --inSrc.val_1 <= to_slv(tmp_float);
        inInst <= Common.FSQRT_R;
        inTag <= ('1', 5);
        wait until outTag.ident = 5;
        report to_hex(outDst.val_0);
        report to_hex(outDst.val_1);
        done <= TRUE;
    end process;

end architecture;

