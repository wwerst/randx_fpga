---------------------------------------------------------------------

-- Common stuff

-- This file provides convenience things required in multiple other files,
-- so we stop getting errors about things being defined twice.

-- Packages included are
--      AVR- general AVR constants

-- Entities included are:
--      AdderBit- single bit full adder

-- Revision History:
--      06 Feb 21   Eric Chen   Add word/address size constants
--                              copy adderbit in from alu
--      13 Feb 21   Eric Chen   Create status bit constants

---------------------------------------------------------------------

--
-- Package defining constants and types for the AVR.
-- This includes the word and address sizes,
-- and constants for accessing the status bits.
--

library ieee;
use ieee.std_logic_1164.all;

package AVR is

    constant WORDSIZE  : natural := 8;
    constant ADDRSIZE: natural := 16;
    subtype word_t is std_logic_vector(WORDSIZE-1 downto 0);
    subtype addr_t is std_logic_vector(ADDRSIZE-1 downto 0);

    -- Single register data bus type
    subtype reg_s_data_t is word_t;
    -- Single register select bus type
    subtype reg_s_sel_t is std_logic_vector(4 downto 0);

    -- Double register data bus type
    subtype reg_d_data_t is std_logic_vector(2*WORDSIZE-1 downto 0);

    subtype reg_d_sel_t is std_logic_vector(1 downto 0);

    constant STATUS_INT: integer := 7;
    constant STATUS_TRANS: integer := 6;
    constant STATUS_HCARRY: integer := 5;
    constant STATUS_SIGN: integer := 4;
    constant STATUS_OVER: integer := 3;
    constant STATUS_NEG: integer := 2;
    constant STATUS_ZERO: integer := 1;
    constant STATUS_CARRY: integer := 0;

end package;

--
--  AdderBit
--
--  This is a bit of the adder for doing addition in the ALU.
--
--  Inputs:
--    A  - first operand bit (bus A)
--    B  - second operand bit (bus B)
--    Ci - carry in (from previous bit)
--
--  Outputs:
--    S  - sum for this bit
--    Co - carry out for this bit
--

library ieee;
use ieee.std_logic_1164.all;

entity  AdderBit  is

    port(
        A  : in   std_logic;        -- first operand
        B  : in   std_logic;        -- second operand
        Ci : in   std_logic;        -- carry in from previous bit
        S  : out  std_logic;        -- sum (result)
        Co : out  std_logic         -- carry out to next bit
    );

end  AdderBit;


architecture  dataflow  of  AdderBit  is
begin

    S  <=  A  xor  B  xor  Ci;
    Co <=  (A  and  B)  or  (A  and Ci)  or  (B  and  Ci);

end  dataflow;
