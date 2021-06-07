----------------------------------------
--! @file
--! @brief Testbench for the scratchpad
--! @brief This testbench is not fully functional yet.
--! @author Will Werst
--! @date   May/June 2021
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


entity ScratchpadTB is
end ScratchpadTB;

architecture behavioral of ScratchpadTB is

    component Scratchpad
        port (
            clk     : in    std_logic;
            reset   : in    std_logic;
            spad_rd : out   Common.QWord_t;    --! Data read out from scratchpad
            spad_rd_valid : out std_logic;     --! Data on spad_rd is correct for given address
            spad_addr : in  Common.SPadAddr_t; --! Address to read/write from
            spad_rd_en : in std_logic;         --! If 1, then read data from scratchpad. Else, write data to scratchpad.
            spad_wr : in    Common.QWord_t     --! Data to write to scratchpad
        );
    end component;

    
    constant CLK_PERIOD : time := 1 ms;
    signal done : boolean := FALSE;
    
    -- Scratchpad test signals
    signal clk    : std_logic := '0';
    signal reset  : std_logic := '0';
    signal spad_rd       : Common.QWord_t;   
    signal spad_rd_valid : std_logic;    
    signal spad_addr     : Common.SPadAddr_t;
    signal spad_rd_en    : std_logic;        
    signal spad_wr       : Common.QWord_t;

    -- Local scratchpad for test verification
    type tb_scratchpad_arr_t is array (0 to 2 ** Common.SIZE_SPAD_ADDR - 1) of Common.QWord_t;
    signal tb_scratchpad_arr : tb_scratchpad_arr_t;

    -- Number of accesses per bin in testing
    constant NUM_ACCESS_PER_BIN : integer := 500;

    constant TEST_BINS: CovBinType := (
        GenBin(0) &
        GenBin(AtLeast => NUM_ACCESS_PER_BIN, Min => 0, Max => 2 ** Common.SIZE_SPAD_ADDR - 1, NumBin => 256)
    );

    shared variable TestCov : CovPType;

begin

    UUT_Scratchpad: Scratchpad port map
        (
            clk    => clk,
            reset  => reset,
            spad_rd  => spad_rd,
            spad_rd_valid  => spad_rd_valid,
            spad_addr => spad_addr,
            spad_rd_en  => spad_rd_en,
            spad_wr => spad_wr
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
        variable tv_addr   : integer range 0 to 2 ** Common.SIZE_SPAD_ADDR - 1;
        variable tv_data   : std_logic_vector(Common.SIZE_QWORD-1 downto 0);
        variable tv_rd_en  : std_logic;
        variable RV        : RandomPType;
    begin
        SetAlertLogName("ScratchpadTestbench");
        
        TestCov.AddBins(TEST_BINS);

        for i in tb_scratchpad_arr'RANGE loop
            -- Clear out the testbench scratchpad
            tb_scratchpad_arr(i) <= (others => '-');
        end loop;
        wait until rising_edge(clk);
        
        while not TestCov.IsCovered loop

            -- Sample opcode
            tv_addr := TestCov.GetRandPoint;
            tv_data := RV.RandSlv(Common.SIZE_QWORD);
            tv_rd_en := RV.RandSlv(1)(1);
            if tv_rd_en = '0' then
                -- Doing write, so save the data
                tb_scratchpad_arr(tv_addr) <= tv_data;
            end if;
            spad_wr <= tv_data;
            spad_addr <= std_logic_vector(to_unsigned(tv_addr, Common.SIZE_SPAD_ADDR));
            spad_rd_en <= tv_rd_en;
            
            wait until rising_edge(clk);
            TestCov.ICover(tv_addr);
        end loop;
        TestCov.WriteBin;

        done <= TRUE;
        wait;
    end process;

    MONITOR_PROC: process
        variable monitor_tb_id : integer;
        variable spad_addr_int : integer;
    begin
        monitor_tb_id := GetAlertLogID("scratchpadTestbench", ALERTLOG_BASE_ID);
        while not done loop
            wait until rising_edge(clk);
            wait until falling_edge(clk);
            -- If reading, check if value correct
            if spad_rd_en = '1' and spad_rd_valid = '1' then
                spad_addr_int := to_integer(unsigned(spad_addr));
                AffirmIf(monitor_tb_id, std_match(tb_scratchpad_arr(spad_addr_int), spad_rd), "Value mismatch");
                if not Is_X(tb_scratchpad_arr(spad_addr_int)) then
                    report "Good read";
                end if;
            end if;
        end loop;
        wait;
    end process;

end architecture;

