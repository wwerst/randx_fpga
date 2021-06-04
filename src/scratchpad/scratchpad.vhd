----------------------------------------------------------------------------
--
-- Scratchpad implementation
--
--
----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.Common;

entity Scratchpad is

    port (
        clk     : in    std_logic;
        reset   : in    std_logic;
        spad_rd : out   Common.QWord_t;    --! Data read out from scratchpad
        spad_rd_valid : out std_logic;     --! Data on spad_rd is correct for given address
        spad_addr : in  Common.SPadAddr_t; --! Address to read/write from
        spad_rd_en : in std_logic;         --! If 1, then read data from scratchpad. Else, write data to scratchpad.
        spad_wr : in    Common.QWord_t     --! Data to write to scratchpad
    );
end Scratchpad;

architecture dataflow of Scratchpad is
    subtype memory_arr_t is array (0 to SIZE_SPAD_ADDR-1) of Common.QWord_t;
    signal memory_s : memory_arr_t
begin

    ReadWriteProc: process(clk)
    begin
        spad_rd <= (others => 'X');
        spad_rd_valid <= '0';
        if rising_edge(clk) then
            if spad_rd_en = '1' then
                spad_rd <= memory_s(spad_addr);
                spad_rd_valid <= '1';
            else
                memory_s(spad_addr) <= spad_wr;
            end if;
        end if;
    end process;

end architecture;