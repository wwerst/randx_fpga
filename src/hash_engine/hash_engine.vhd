----------------------------------------
--! @file
--! @brief Template brief statement
--! @author Will Werst
--! @date   May 2021
----------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Common;


entity HashEngine is

    generic (
        some_generic : numeric := 10
    );
    port (
        clk   : in std_logic;
        reset : in std_logic;
        some_out : out std_logic 
        );
end HashEngine;

architecture behavioral of HashEngine is
begin
end architecture behavioral;
