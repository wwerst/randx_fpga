---------------------------------------------------------------------
--
-- RandomX CPU Testbench
--
---------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

library osvvm;
use osvvm.CoveragePkg.all;
use osvvm.AlertLogPkg.all;

entity randomx_cpu_tb is
end randomx_cpu_tb;

architecture testbench of randomx_cpu_tb is

    -- test bench clock and done
    constant CLK_PERIOD : time := 1 ms;
    signal clk          : std_logic := '0';
    signal done         : boolean := FALSE;
    constant MAX_ERROR_COUNT : integer := 2;

begin
    clock_p: process begin
        while not done loop
            clk <= '1';
            wait for CLK_PERIOD/2;
            clk <= '0';
            wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;

end architecture testbench;

