---------------------------------------------------------------------
--! @file
--! @brief RandomX config parameters
--! @author Will Werst
--! @date   June 2021
---------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! RdxCfg
--
--! This package contains various constants specified for the RandomX hash.
package RdxCfg is

    -- Constants
    constant RANDOMX_PROGRAM_SIZE : natural := 256;
    constant RANDOMX_PROGRAM_ITERATIONS : natural := 2048;
    constant RANDOMX_PROGRAM_COUNT : natural := 8;
    constant RANDOMX_SCRATCHPAD_L3 : natural := 2097152;
    constant RANDOMX_SCRATCHPAD_L2 : natural := 262144;
    constant RANDOMX_SCRATCHPAD_L1 : natural := 16384;

    constant LOG2_RANDOMX_SCRATCHPAD_L3 : natural := 21;


end package;

