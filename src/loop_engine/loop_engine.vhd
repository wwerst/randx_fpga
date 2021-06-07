----------------------------------------
--! @file
--! @brief Execute the 256 instruction program as defined in
--! @brief 4.6.2 in RandomX_specs.pdf
--
--! @author Will Werst
--! @date   May/June 2021
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

architecture dataflow of LoopEngine is

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

    signal intALU_inDst  :  Common.IntReg_t;
    signal intALU_inSrc  :  Common.IntReg_t;
    signal intALU_inInst :  Common.ReducedInst_t;
    signal intALU_inTag  :  Common.OpTag_t;
    signal intALU_outDst :  Common.IntReg_t;
    signal intALU_outTag :  Common.OpTag_t;

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

    signal floatALU_inDst  :  Common.FloatReg_t;
    signal floatALU_inSrc  :  Common.FloatReg_t;
    signal floatALU_inInst :  Common.ReducedInst_t;
    signal floatALU_inTag  :  Common.OpTag_t;
    signal floatALU_outDst :  Common.FloatReg_t;
    signal floatALU_outTag :  Common.OpTag_t;

    type program_arr_t is array (0 to num_instructions) of Common.ReducedInst_t;
    signal program_s   : program_arr_t;

    signal cur_inst_s  : Common.ReducedInst_t;

    signal cur_inst_src4 : integer range 0 to 3;
    signal cur_inst_dst4 : integer range 0 to 3;
    signal cur_inst_src8 : integer range 0 to 7;
    signal cur_inst_dst8 : integer range 0 to 7;

    signal reg_table_s : Common.RegTable_t;

    type ProgState_t is (Ready, Running, Done);
    signal prog_state_s : ProgState_t;
    signal next_prog_state_s : ProgState_t;

    signal prog_counter_s : integer range 0 to num_instructions-1;
    signal next_prog_counter : integer range 0 to num_instructions-1;
    signal prog_is_terminating : std_logic; -- Signals that we are at final instruction.

    signal spad_rd_r_convert  : Common.IntReg_t;
    signal spad_rd_f_convert  : Common.FloatReg_t;
    signal spad_rd_e_convert  : Common.FloatReg_t;
begin


    -- Setup the integer ALU
    IntALUUnit: IntALU port map
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

    -- Setup the float ALU
    FloatALUUnit: FloatALU port map
        (
            clk         => clk,
            reset       => reset,
            inDst       => floatALU_inDst,
            inSrc       => floatALU_inSrc,
            inInst      => floatALU_inInst,
            inTag       => floatALU_inTag,
            outDst      => floatALU_outDst,
            outTag      => floatALU_outTag
    );


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
                    next_prog_state_s <= Running;
                else
                    next_prog_state_s <= Ready;
                end if;
            elsif prog_state_s = Running then
                -- Program is running
                if prog_is_terminating = '1' then
                    next_prog_state_s <= Done;
                else
                    next_prog_state_s <= Running;
                end if;
            end if;
        end if;
    end process NextProgStateProcess;

    cur_inst_s <= program_s(prog_counter_s);
    cur_inst_src4 <= to_integer(cur_inst_s.src(1 downto 0));
    cur_inst_dst4 <= to_integer(cur_inst_s.dst(1 downto 0));
    cur_inst_src8 <= to_integer(cur_inst_s.src(2 downto 0));
    cur_inst_dst8 <= to_integer(cur_inst_s.dst(2 downto 0));

    spad_rd_r_convert <=  spad_rd;
    spad_rd_f_convert <= (spad_rd, spad_rd); -- This is incorrect. See Chapter 4.3.1
    spad_rd_e_convert <= (spad_rd, spad_rd); -- This is incorrect. See Chapter 4.3.2


    -- The inTag is intended for Tomasulo algorithm, but currently not implemented.
    intALU_inTag <= ('1', 0);
    floatALU_inTag <= ('1', 0);

    -- The inInst is hard-wired for now
    intALU_inInst <= cur_inst_s;
    floatALU_inInst <= cur_inst_s;


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
            -- Run the program. This deals with mapping instructions to ALUs
            case cur_inst_s.opcode is
                when Common.IADD_RS =>
                    intALU_inSrc <= reg_table_s.r(cur_inst_src8);
                    intALU_inDst <= reg_table_s.r(cur_inst_dst8);
                when Common.IADD_M  =>
                    intALU_inSrc <= spad_rd_r_convert;
                    intALU_inDst <= reg_table_s.r(cur_inst_dst8);
                when Common.ISUB_R  =>
                    intALU_inSrc <= reg_table_s.r(cur_inst_src8);
                    intALU_inDst <= reg_table_s.r(cur_inst_dst8);
                when Common.ISUB_M  =>
                    intALU_inSrc <= spad_rd_r_convert;
                    intALU_inDst <= reg_table_s.r(cur_inst_dst8);
                when Common.IMUL_R  =>
                    intALU_inSrc <= reg_table_s.r(cur_inst_src8);
                    intALU_inDst <= reg_table_s.r(cur_inst_dst8);
                when Common.IMUL_M  =>
                    intALU_inSrc <= spad_rd_r_convert;
                    intALU_inDst <= reg_table_s.r(cur_inst_dst8);
                when Common.IMULH_R  =>
                    intALU_inSrc <= reg_table_s.r(cur_inst_src8);
                    intALU_inDst <= reg_table_s.r(cur_inst_dst8);
                when Common.IMULH_M  =>
                    intALU_inSrc <= spad_rd_r_convert;
                    intALU_inDst <= reg_table_s.r(cur_inst_dst8);
                when Common.ISMULH_R  =>
                    intALU_inSrc <= reg_table_s.r(cur_inst_src8);
                    intALU_inDst <= reg_table_s.r(cur_inst_dst8);
                when Common.ISMULH_M  =>
                    intALU_inSrc <= spad_rd_r_convert;
                    intALU_inDst <= reg_table_s.r(cur_inst_dst8);
                when Common.IMUL_RCP  =>
                    intALU_inSrc <= reg_table_s.r(cur_inst_src8);
                    intALU_inDst <= reg_table_s.r(cur_inst_dst8);
                when Common.INEG_R  =>
                    intALU_inSrc <= reg_table_s.r(cur_inst_src8);
                    intALU_inDst <= reg_table_s.r(cur_inst_dst8);
                when Common.IXOR_R  =>
                    intALU_inSrc <= reg_table_s.r(cur_inst_src8);
                    intALU_inDst <= reg_table_s.r(cur_inst_dst8);
                when Common.IXOR_M  =>
                    intALU_inSrc <= spad_rd_r_convert;
                    intALU_inDst <= reg_table_s.r(cur_inst_dst8);
                when Common.IROR_R  =>
                    intALU_inSrc <= reg_table_s.r(cur_inst_src8);
                    intALU_inDst <= reg_table_s.r(cur_inst_dst8);
                when Common.IROL_R  =>
                    intALU_inSrc <= reg_table_s.r(cur_inst_src8);
                    intALU_inDst <= reg_table_s.r(cur_inst_dst8);
                when Common.ISWAP_R  =>
                    -- TODO(WHW): Determine best way to implement this.
                    null;
                when Common.FSWAP_R  =>
                    -- TODO(WHW): Determine best way to implement this.
                    null;
                when Common.FADD_R  =>
                    floatALU_inSrc <= reg_table_s.a(cur_inst_src4);
                    floatALU_inDst <= reg_table_s.f(cur_inst_dst4);
                when Common.FADD_M  =>
                    floatALU_inSrc <= spad_rd_f_convert;
                    floatALU_inDst <= reg_table_s.f(cur_inst_dst4);
                when Common.FSUB_R  =>
                    floatALU_inSrc <= reg_table_s.a(cur_inst_src4);
                    floatALU_inDst <= reg_table_s.f(cur_inst_dst4);
                when Common.FSUB_M  =>
                    floatALU_inSrc <= spad_rd_f_convert;
                    floatALU_inDst <= reg_table_s.f(cur_inst_dst4);
                when Common.FSCAL_R  =>
                    floatALU_inSrc <= reg_table_s.a(cur_inst_src4); -- Not needed
                    floatALU_inDst <= reg_table_s.f(cur_inst_dst4);
                when Common.FMUL_R  =>
                    floatALU_inSrc <= reg_table_s.a(cur_inst_src4);
                    floatALU_inDst <= reg_table_s.e(cur_inst_dst4);
                when Common.FDIV_M  =>
                    floatALU_inSrc <= spad_rd_e_convert;
                    floatALU_inDst <= reg_table_s.e(cur_inst_dst4);
                when Common.FSQRT_R  =>
                    floatALU_inSrc <= reg_table_s.a(cur_inst_src4); -- Not needed
                    floatALU_inDst <= reg_table_s.e(cur_inst_dst4);
                when Common.CBRANCH  =>
                    -- TODO(WHW): Implement branching
                    null;
                when Common.CFROUND  =>
                    -- TODO(WHW): Implement floating point rounding. Likely not feasible
                    -- because custom floating point unit is quite complicated.
                when Common.ISTORE  =>
                    -- TODO(WHW): Implement
                    null;
                when Common.NOP  =>
                when others =>
                    null;
            end case;
        elsif prog_state_s = Done then
            null;
        end if;
    end process ProgRunProcess;


end architecture dataflow;
