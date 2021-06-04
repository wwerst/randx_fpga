----------------------------------------
--! @file
--! @brief Execute the 256 instruction program as defined in
--! @brief 4.6.2 in RandomX_specs.pdf
--! @author Will Werst
--! @date   May 2021
----------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Common;
use work.FloatALU;
use work.IntAlu;

--! Executes the given 256 RandomX instructions when commanded.

--! The reg_table_in is used as the initial register file. Interfaces for the
--! external scratchpad are connected. The program is shifted in 1 instruction
--! at a time  and when start_prog
--! goes from '0' to '1' at clk, the program runs. When 'prog_done' is
entity LoopEngine is

    generic (
        num_instructions : natural := 256
    );
    port (
        clk            : in std_logic;            --! Clock signal
        reset          : in std_logic;            --! Active-high reset
        reg_table_in   : in Common.RegTable_t;    --! Initial register table
        prog_in_inst   : in Common.ReducedInst_t; --! Instruction to load if prog_in_enable = 1
        prog_in_addr   : in integer range 0 to num_instructions-1; --! Program address to load in if prog_in_enable = 1 
        prog_in_enable : in std_logic;            --! If prog_done is 1, then load the prog_in_inst
        start_prog     : in std_logic;            --! On rising edge, this triggers program execution.
        spad_rd        : in Common.QWord_t;       --! Scratchpad read input
        spad_rd_valid  : in std_logic;            --! Scratchpad read input valid
        spad_addr      : out Common.SPadAddr_t;   --! Scratchpad read/write address
        spad_rd_en     : out std_logic;           --! If 1, then read data from scratchpad. Else, write data to scratchpad.
        spad_wr       : out Common.QWord_t;       --! Scratchpad write output
        prog_done      : out std_logic;           --! 0 when a program is running, and 1 when program is done or not running.
        reg_table_out  : out Common.RegTable_t    --! Final register table after program execution.
        );
end LoopEngine;

architecture behavioral of LoopEngine is

    component IntALU
        port (
            clk         :  in     std_logic;                       -- system clock
            reset       :  in     std_logic;                       -- reset signal (active low)
            inDst       :  in     Common.IntReg_t;                 -- Integer operand A
            inSrc       :  in     Common.IntReg_t;                 -- Integer operand B
            inInst      :  in     Common.ReducedInst_t;            -- Operation to apply
            inTag       :  in     Common.OpTag_t;                  -- Operand tag (for Tomasulo)
            outDst      :  out    Common.intreg_t;
            outTag      :  out    Common.OpTag_t
        );
    end component;

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

    type program_arr_t is array (0 to num_instructions) of Common.ReducedInst_t;
    signal program_s   : program_arr_t;

    signal cur_inst_s  : Common.ReducedInst_t;

    signal reg_table_s : Common.RegTable_t;

    type ProgState_t is (Ready, Running, Done);
    signal prog_state_s : ProgState_t;
    signal next_prog_state_s : ProgState_t;

    signal prog_counter : integer range 0 to num_instructions-1;
begin
    -- Connect up outputs
    prog_done <= '1' when prog_state_s = Done else '0';
    reg_table_out <= reg_table_s;

    -- Load the program instructions
    LoadProgProcess: process(clk)
    begin
        if rising_edge(clk) then
            if prog_in_enable = '1' and prog_state_s = Done then
                -- If no program is running and a new instruction is specified,
                -- load it.
                program_s(prog_in_addr) <= prog_in_inst;
            end if;
        end if;
    end process LoadProgProcess;

    -- Load the synchronized program state
    ProgStateStorageProcess: process(clk)
    begin
        if rising_edge(clk) then
            -- Load the next program state
            prog_state_s <= next_prog_state_s;
        end if;
    end process ProgStateStorageProcess;

    NextProgStateProcess: process(all)
    begin
        if reset = '1' then
            next_prog_state_s <= Ready;
        else
            -- Specify defaults to latch reg_table_s
            reg_table_s <= reg_table_s;
            if prog_state_s = Ready then
                if start_prog = '1' then
                    -- Starting a new program iteration
                    reg_table_s <= reg_table_in;
                    prog_state_s <= Running;
                else
                    prog_state_s <= Ready;
                end if;
            elsif prog_state_s = Running then
            end if;
        end if;
    end process NextProgStateProcess;

    -- This is the process that manages running of the programs.
    -- It manages the prog_counter, and 
    ProgRunProcess: process(clk)
    begin
        -- If the program is starting again, then load the reg_table_in
        if prog_state_s = Ready then
            if next_prog_state_s = Running then
                reg_table_s <= reg_table_in;
            end if;
        elsif prog_state_s = Running then
            -- Run the program
            case cur_inst_s.opcode is
                when Common.IADD_RS =>
                when Common.IADD_M  =>
                when Common.ISUB_R  =>
                when Common.ISUB_M  =>
                when Common.IMUL_R  =>
                when Common.IMUL_M  =>
                when Common.IMULH_R  =>
                when Common.IMULH_M  =>
                when Common.ISMULH_R  =>
                when Common.ISMULH_M  =>
                when Common.IMUL_RCP  =>
                when Common.INEG_R  =>
                when Common.IXOR_R  =>
                when Common.IXOR_M  =>
                when Common.IROR_R  =>
                when Common.IROL_R  =>
                when Common.ISWAP_R  =>
                when Common.FSWAP_R  =>
                when Common.FADD_R  =>
                when Common.FADD_M  =>
                when Common.FSUB_R  =>
                when Common.FSUB_M  =>
                when Common.FSCAL_R  =>
                when Common.FMUL_R  =>
                when Common.FDIV_M  =>
                when Common.FSQRT_R  =>
                when Common.CBRANCH  =>
                when Common.CFROUND  =>
                when Common.ISTORE  =>
                when Common.NOP  =>
                when others =>
                    null;
            end case;
        elsif prog_state_s = Done then
            null;
        end if;
    end process ProgRunProcess;


end architecture behavioral;
