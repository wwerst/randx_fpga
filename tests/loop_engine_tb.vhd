----------------------------------------
--! @file
--! @brief Testbench for the loop engine
--! @brief This is still in progress. Loop Engine is somewhat of a monolith.
--! @author Will Werst
--! @date   May/June 2021
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


entity LoopEngineTB is
    generic (
        program_filename    : string;
        scratchpad_filename : string
    );
end LoopEngineTB;

architecture behavioral of LoopEngineTB is

    component LoopEngine
        generic (
            num_instructions : natural := RdxCfg.RANDOMX_PROGRAM_SIZE
        );
        port (
            clk            : in std_logic;
            reset          : in std_logic;
            reg_table_in   : in Common.RegTable_t;
            prog_in_inst   : in Common.ReducedInst_t;
            prog_in_addr   : in integer range 0 to num_instructions-1;
            prog_in_enable : in std_logic; 
            start_prog     : in std_logic; 
            spad_rd        : in Common.QWord_t;
            spad_rd_valid  : in std_logic;
            spad_addr      : out Common.SPadAddr_t;
            spad_rd_en     : out std_logic;
            spad_wr        : out Common.QWord_t;
            prog_done      : out std_logic; 
            reg_table_out  : out Common.RegTable_t
            );
    end component;

    component ScratchpadUnBound
        port (
            clk     : in    std_logic;
            reset   : in    std_logic;
            spad_rd : out   Common.QWord_t;
            spad_rd_valid : out std_logic;
            spad_addr : in  Common.SPadAddr_t;
            spad_rd_en : in std_logic;
            spad_wr : in    Common.QWord_t
        );
    end component;

    
    constant CLK_PERIOD : time := 1 ms;
    signal done : boolean := FALSE;
    
    -- Loop Engine signals
    signal clk : std_logic := '0';
    signal reset : std_logic := '0';
    signal reg_table_in   : Common.RegTable_t;
    signal prog_in_inst   : Common.ReducedInst_t;
    signal prog_in_addr   : integer range 0 to RdxCfg.RANDOMX_PROGRAM_SIZE-1;
    signal prog_in_enable : std_logic; 
    signal start_prog     : std_logic; 
    signal spad_rd        : Common.QWord_t;
    signal spad_rd_valid  : std_logic;
    signal spad_addr      : Common.SPadAddr_t;
    signal spad_rd_en     : std_logic;
    signal spad_wr        : Common.QWord_t;
    signal prog_done      : std_logic; 
    signal reg_table_out  : Common.RegTable_t;


    type prog_inst_arr_t is array (0 to 255) of std_logic_vector(63 downto 0);

    type scratchpad_arr_t is array (0 to (2097152/8)-1) of std_logic_vector(63 downto 0);

    signal ProgInstructions : prog_inst_arr_t;
    signal Scratchpad_data  : scratchpad_arr_t;

    function to_hex(slv : std_logic_vector) return string is
        variable l : line;
    begin
        hwrite(l, slv);
        return l.all;
    end to_hex;

    function to_opcode(opcode_raw : std_logic_vector(7 downto 0)) return Common.RandX_Op_t is
        variable opc_unsigned : unsigned(7 downto 0);
    begin
        opc_unsigned := unsigned(opcode_raw);
        if opc_unsigned < 10 then
            return Common.IADD_RS;
        elsif opc_unsigned < 20 then
            return Common.IADD_M;
        end if;
        return Common.NOP;
    end to_opcode;

    function raw_to_reduced_inst(raw_inst : Common.RawInst_t) return Common.ReducedInst_t is
        variable imm32       : signed(31 downto 0);
        variable mod_mem     : unsigned(1 downto 0);
        variable mod_shift   : unsigned(1 downto 0);
        variable mod_cond    : unsigned(3 downto 0);
        variable src         : unsigned(2 downto 0);
        variable dst         : unsigned(2 downto 0);
        variable opcode      : Common.RandX_Op_t;
        variable reduced_inst : Common.ReducedInst_t;
    begin
        imm32 := signed(raw_inst.imm32);
        mod_mem := unsigned(raw_inst.mod_field(1 downto 0));
        mod_shift := unsigned(raw_inst.mod_field(3 downto 2));
        mod_cond := unsigned(raw_inst.mod_field(7 downto 4));
        src := unsigned(raw_inst.src(2 downto 0));
        dst := unsigned(raw_inst.dst(2 downto 0));
        opcode := to_opcode(raw_inst.opcode);
        reduced_inst := (
            imm32,
            mod_mem,
            mod_shift,
            mod_cond,
            src,
            dst,
            opcode);
        return reduced_inst;
    end raw_to_reduced_inst;

begin

    UUT: LoopEngine port map
        (
            clk            => clk           ,
            reset          => reset         ,
            reg_table_in   => reg_table_in  ,
            prog_in_inst   => prog_in_inst  ,
            prog_in_addr   => prog_in_addr  ,
            prog_in_enable => prog_in_enable,
            start_prog     => start_prog    ,
            spad_rd        => spad_rd       ,
            spad_rd_valid  => spad_rd_valid ,
            spad_addr      => spad_addr     ,
            spad_rd_en     => spad_rd_en    ,
            spad_wr        => spad_wr       ,
            prog_done      => prog_done     ,
            reg_table_out  => reg_table_out
    );

    externScratchpad: ScratchpadUnbound port map
        (
            clk           => clk,
            reset         => reset,
            spad_rd       => spad_rd,
            spad_rd_valid => spad_rd_valid,
            spad_addr     => spad_addr,
            spad_rd_en    => spad_rd_en,
            spad_wr       => spad_wr
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

    TEST_PROC: process
        file program_file    : text is program_filename;
        file scratchpad_file : text is scratchpad_filename;
        variable linenum     : integer := 0;
        variable line_buf: line;
        variable long_std_vec: std_logic_vector(63 downto 0);
        variable raw_inst : Common.RawInst_t;
        variable cur_inst_slv : std_logic_vector(63 downto 0);
    begin
        prog_in_enable <= '0';
        -- Load the program data
        linenum := 0;
        while not endfile(program_file) loop
            readline(program_file, line_buf);
            hread(line_buf, long_std_vec);
            ProgInstructions(linenum) <= long_std_vec;
            linenum := linenum + 1;
        end loop;
        -- Load the scratchpad data
        linenum := 0;
        while not endfile(scratchpad_file) loop
            readline(scratchpad_file, line_buf);
            hread(line_buf, long_std_vec);
            Scratchpad_data(linenum) <= long_std_vec;
            linenum := linenum + 1;
        end loop;
        wait for 100 ms;
        for linenum in ProgInstructions'range loop
            -- Load the instructions into loop_engine
            -- This slicing is defined in RandomX_specs.pdf
            cur_inst_slv := ProgInstructions(linenum);
            raw_inst := (
                cur_inst_slv(63 downto 32),  -- imm32
                cur_inst_slv(31 downto 24),  -- mod_field
                cur_inst_slv(23 downto 16),  -- src
                cur_inst_slv(15 downto 8),   -- dst
                cur_inst_slv(7 downto 0));    -- opcode)
            prog_in_inst <= raw_to_reduced_inst(raw_inst);
        end loop;
        done <= TRUE;
        wait;
    end process;

end architecture;

