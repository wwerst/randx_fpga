----------------------------------------------------------------------------
--
--  Atmel AVR CPU
--
--  This is the implementation of the complete AVR CPU.
--
--  Revision History:
--     11 May 98  Glen George       Initial revision.
--      9 May 00  Glen George       Updated comments.
--      7 May 02  Glen George       Updated comments.
--     21 Jan 08  Glen George       Updated comments.
--     22 Feb 21  Eric Chen         Start sketching implementation
--     27 Mar 21  Will Werst        Implement full cpu. See git
--                                  history for more granular details
--                                  and revision history.
--     27 Mar 21  Will Werst        Pipeline cpu.
----------------------------------------------------------------------------


--
--  AVR_CPU
--
--  Inputs:
--    ProgDB - program memory data bus (16 bits)
--    Reset  - active low reset signal
--    INT0   - active low interrupt. Not used.
--    INT1   - active low interrupt. Not used.
--    clock  - the system clock
--
--  Outputs:
--    ProgAB - program memory address bus (16 bits)
--    DataAB - data memory address bus (16 bits)
--    DataWr - data write signal
--    DataRd - data read signal
--
--  Inputs/Outputs:
--    DataDB - data memory data bus (8 bits)
--

library ieee;
use ieee.std_logic_1164.all;
--use ieee.std_logic_arith.all;
use ieee.numeric_std.all;

use work.opcodes;
use work.AVR;
use work.IAU;
use work.DAU;
use work.ALUOp;

entity  AVR_CPU  is

    port (
        ProgDB  :  in     std_logic_vector(15 downto 0);   -- program memory data bus
        Reset   :  in     std_logic;                       -- reset signal (active low)
        INT0    :  in     std_logic;                       -- interrupt signal (active low)
        INT1    :  in     std_logic;                       -- interrupt signal (active low)
        clock   :  in     std_logic;                       -- system clock
        ProgAB  :  out    std_logic_vector(15 downto 0);   -- program memory address bus
        DataAB  :  out    std_logic_vector(15 downto 0);   -- data memory address bus
        DataWr  :  out    std_logic;                       -- data memory write enable (active low)
        DataRd  :  out    std_logic;                       -- data memory read enable (active low)
        DataDB  :  inout  std_logic_vector(7 downto 0)     -- data memory data bus
    );

end  AVR_CPU;

architecture dataflow of AVR_CPU is

    component AvrIau is
        port(
            clk         : in  std_logic;
            reset       : in  std_logic;
            SrcSel      : in  IAU.source_t;
            branch      : in  std_logic_vector(6 downto 0);
            jump        : in  std_logic_vector(11 downto 0);
            PDB         : in  AVR.addr_t;
            DDB         : in  std_logic_vector(7 downto 0);
            Z           : in  AVR.addr_t;
            OffsetSel   : in  IAU.offset_t;
            BackPress   : in  std_logic;
            Address     : out AVR.addr_t
        );
    end component;
    signal iau_branch      : std_logic_vector(6 downto 0);
    signal iau_jump        : std_logic_vector(11 downto 0);
    type iau_ctrl_t is record
        srcSel: IAU.source_t;
        offsetSel: IAU.offset_t;
    end record;
    signal iau_ctrl: iau_ctrl_t;


    component AvrReg is
        port (
            clk         : in std_logic;
            -- Single register input
            EnableInS   : in std_logic;
            DataInS     : in AVR.reg_s_data_t;
            SelInS      : in AVR.reg_s_sel_t;
            -- Double register input
            EnableInD   : in std_logic;
            DataInD     : in AVR.reg_d_data_t;
            SelInD      : in AVR.reg_d_sel_t;
            -- Single register A output
            SelOutA     : in AVR.reg_s_sel_t;
            DataOutA    : out AVR.reg_s_data_t;
            -- Single register B output
            SelOutB     : in AVR.reg_s_sel_t;
            DataOutB    : out AVR.reg_s_data_t;
            -- Double register output
            SelOutD     : in AVR.reg_d_sel_t;
            DataOutD    : out AVR.reg_d_data_t
        );
    end component;

    type reg_read_ctrl_t is record
        -- Single register output selects
        SelOutA     : AVR.reg_s_sel_t;
        SelOutB     : AVR.reg_s_sel_t;
        -- Double register output selects
        SelOutD     : AVR.reg_d_sel_t;
    end record;
    signal reg_read_ctrl : reg_read_ctrl_t;

    -- Single register outputs
    signal reg_DataOutA    : AVR.reg_s_data_t;
    signal reg_DataOutB    : AVR.reg_s_data_t;
    -- Double register output
    signal reg_DataOutD    : AVR.reg_d_data_t;

    -- Single register delayed outputs
    -- Used for MUL instruction to remember the previous values
    -- for registers, for cases when input registers are being
    -- overwritten.
    signal reg_DataOutA_delay : AVR.reg_s_data_t;
    signal reg_DataOutB_delay : AVR.reg_s_data_t;

    type reg_write_ctrl_t is record
        -- Single register input select
        EnableInS   : std_logic;
        SelInS      : AVR.reg_s_sel_t;
        -- Double register input select
        EnableInD   : std_logic;
        SelInD      : AVR.reg_d_sel_t;
    end record;
    signal reg_write_ctrl : reg_write_ctrl_t;
    -- Single register input
    signal reg_DataInS     : AVR.reg_s_data_t;
    -- Double register input
    signal reg_DataInD     : AVR.reg_d_data_t;


    component AvrDau is
        port(
            clk         : in  std_logic;
            reset       : in  std_logic;
            SrcSel      : in  DAU.source_t;
            PDB         : in  std_logic_vector(15 downto 0);
            reg         : in  std_logic_vector(15 downto 0);
            OffsetSel   : in  DAU.offset_t;
            array_off   : in  std_logic_vector(5 downto 0);
            BackPress   : in  std_logic;
            Address     : out AVR.addr_t;
            Update      : out AVR.addr_t
        );
    end component;
    signal dau_array_off   : std_logic_vector(5 downto 0);
    signal dau_update      : AVR.addr_t;
    type dau_ctrl_t is record
        SrcSel      : DAU.source_t;
        OffsetSel   : DAU.offset_t;
    end record;
    signal dau_ctrl: dau_ctrl_t;

    component avr_alu is
        port(
            clk         : in   std_logic;
            ALUOpA      : in   AVR.word_t;   -- first operand
            ALUOpB      : in   AVR.word_t;   -- second operand
            ALUOpSelect : in   ALUOp.ALUOP_t;
            FlagMask    : in   AVR.word_t;   -- Flag mask. If 1, then update bit. If 0, leave bit unchanged.
            Status      : out  AVR.word_t;   -- Status register
            Result      : out  AVR.word_t    -- Output result
        );
    end component;
    signal alu_SReg     : AVR.word_t;   -- Status register
    signal alu_Result   : AVR.word_t;   -- Output result


    signal InstReg: std_logic_vector(15 downto 0);
    signal InstPayload: std_logic_vector(15 downto 0);
    signal ProgDBSync: std_logic_vector(15 downto 0);

    signal LoadInstReg: std_logic;
    signal LoadInstPayload: std_logic;

    signal decodeReg16d : AVR.reg_s_sel_t;
    signal decodeReg32d : AVR.reg_s_sel_t;
    signal decodeReg32r : AVR.reg_s_sel_t;

    signal DecodeDataHazardPresent : std_logic;

    -- Decode signal for double register's
    -- corresponding low and high single reg address
    signal decodeDRegLow  : AVR.reg_s_sel_t;
    signal decodeDRegHigh : AVR.reg_s_sel_t;

    -- Decode signal for constants
    signal decodeWordConstant : AVR.word_t;
    signal decodeASDIWConstant : AVR.word_t;

    signal decodeBitIndexB : integer range 0 to 7;
    signal decodeBitIndexS : integer range 0 to 7;


    signal startDataRd, startDataWr: std_logic;

    -- state machine
    subtype decode_state_t is integer range 0 to 3;
    signal CurState: decode_state_t;

    type execute_op_data_t is record
        OpA            : AVR.word_t;
        OpB            : AVR.word_t;
        ALUOpCode      : ALUOp.ALUOP_t;
        ALUFlagMask    : AVR.word_t;
        writeRegEnS    : std_logic;
        writeRegSelS   : AVR.reg_s_sel_t;
        dataD          : AVR.addr_t;
        writeRegEnD    : std_logic;
        writeRegSelD   : AVR.reg_d_sel_t;
    end record;

    signal CurExecuteOpData, NextExecuteOpData : execute_op_data_t;

    type write_op_data_t is record
        dataS          : AVR.word_t;
        writeRegEnS    : std_logic;
        writeRegSelS   : AVR.reg_s_sel_t;
        dataD          : AVR.addr_t;
        writeRegEnD    : std_logic;
        writeRegSelD   : AVR.reg_d_sel_t;
    end record;

    signal decodeDataReadLocks : std_logic_vector(39 downto 0);
    signal decodeDataWriteLocks : std_logic_vector(39 downto 0);
    signal executeDataLocks : std_logic_vector(39 downto 0);
    signal writeDataLocks : std_logic_vector(31 downto 0);
    signal decodeExecuteHazards : std_logic_vector(39 downto 0);
    signal decodeWriteHazards : std_logic_vector(31 downto 0);

    signal DecodeUsedSreg : std_logic;

    signal CurWriteOpData, NextWriteOpData : write_op_data_t;

    signal SyncReset : std_logic;

    -- Used to read signal internally.
    -- Note, could make external signal a buffer,
    -- but this changes interface.
    signal ProgABBuf : std_logic_vector(15 downto 0);

    constant FlagMaskAll    :  AVR.word_t := "11111111";
    constant FlagMaskNone   :  AVR.word_t := "00000000";
    constant FlagMaskZCNVSH :  AVR.word_t := "00111111";
    constant FlagMaskZCNVS  :  AVR.word_t := "00011111";
    constant FlagMaskCNVS   :  AVR.word_t := "00011101";
    constant FlagMaskCNVSH  :  AVR.word_t := "00111101";
    constant FlagMaskZNVS   :  AVR.word_t := "00011110";
    constant FlagMaskZC     :  AVR.word_t := "00000011";
    constant FlagMaskT      :  AVR.word_t := "01000000";



begin




    reg_u: AvrReg port map (
        clk       => clock,
        EnableInS => reg_write_ctrl.EnableInS,
        DataInS   => reg_DataInS,
        SelInS    => reg_write_ctrl.SelInS,
        EnableInD => reg_write_ctrl.EnableInD,
        DataInD   => reg_DataInD,
        SelInD    => reg_write_ctrl.SelInD,
        SelOutA   => reg_read_ctrl.SelOutA,
        DataOutA  => reg_DataOutA,
        SelOutB   => reg_read_ctrl.SelOutB,
        DataOutB  => reg_DataOutB,
        SelOutD   => reg_read_ctrl.SelOutD,
        DataOutD  => reg_DataOutD
    );

    iau_u: AvrIau port map (
        clk       => clock,
        reset     => Reset,
        SrcSel    => iau_ctrl.srcSel,
        branch    => iau_branch,
        jump      => iau_jump,
        PDB       => InstPayload,
        DDB       => DataDB,
        Z         => reg_DataOutD,
        OffsetSel => iau_ctrl.offsetSel,
        BackPress => DecodeDataHazardPresent,
        Address   => ProgABBuf
    );

    ProgAB <= ProgABBuf;

    dau_u: AvrDau port map (
        clk       => clock,
        reset     => reset,
        SrcSel    => dau_ctrl.SrcSel,
        PDB       => ProgDB,
        reg       => reg_DataOutD,
        OffsetSel => dau_ctrl.OffsetSel,
        array_off => dau_array_off,
        BackPress => DecodeDataHazardPresent,
        Address   => DataAB,
        Update    => dau_update
    );

    alu_u: avr_alu port map (
       clk         => clock,
       ALUOpA      => CurExecuteOpData.OpA,
       ALUOpB      => CurExecuteOpData.OpB,
       ALUOpSelect => CurExecuteOpData.ALUOpCode,
       FlagMask    => CurExecuteOpData.ALUFlagMask,
       Status      => alu_SReg,
       Result      => alu_result
    );

    -- Loads the data from ProgDB
    -- Can either be loaded into the instruction
    -- register normally, or into payload register
    InstrLatchProc: process(clock)
    begin
        if rising_edge(clock) then
            if reset = '0' then
                InstReg <= (others => '0');
                ProgDBSync <= (others => '0');
                CurState <= 0;
            elsif DecodeDataHazardPresent = '1' then
                -- Do nothing to apply backpressure
                -- when the pipeline is stalled.
                null;
            else
                ProgDBSync <= ProgDB;
                if LoadInstReg = '1' then
                    InstReg <= ProgDB;
                    CurState <= 0;
                else
                    CurState <= CurState + 1;
                end if;
                if LoadInstPayload = '1' then
                    InstPayload <= ProgDB;
                end if;
            end if;
        end if;
    end process InstrLatchProc;


    SyncResetProc: process(clock)
    begin
        if rising_edge(clock) then
            SyncReset <= reset;
        end if;
    end process SyncResetProc;

    -- Writes and reads are sent at the falling clock
    -- edge, and then the write signal is cleared at the
    -- rising edge. Thus, the timing requirement is that
    -- the data address is computed and output within 1/2
    -- clock cycle + setup time, and then the write/read occurs
    -- within the half clock cycle before the rising edge of clock.
    -- The DecodeDataHazardPresent signal is also or'ed to
    -- apply backpressure when the pipeline is stalled.
    DataRd <= startDataRd or clock or DecodeDataHazardPresent;
    DataWr <= startDataWr or clock or DecodeDataHazardPresent;

    RegReadDelayProc: process(clock)
    begin
        if rising_edge(clock) then
            reg_DataOutA_delay <= reg_DataOutA;
            reg_DataOutB_delay <= reg_DataOutB;
        end if;
    end process;

    dau_array_off <= InstReg(13) & InstReg(11 downto 10) & InstReg(2 downto 0);
    iau_branch <= InstReg(9 downto 3);
    iau_jump <= InstPayload(11 downto 0);

    -- Common register decodings used in decode logic
    decodeReg16d <= "1" & InstReg(7 downto 4);
    decodeReg32d <= InstReg(8 downto 4);
    decodeReg32r <= InstReg(9) & InstReg(3 downto 0);

    decodeDRegLow <= ("11" & InstReg(5 downto 4) & "0");
    decodeDRegHigh <= ("11" & InstReg(5 downto 4) & "1");

    decodeWordConstant <= (InstReg(11 downto 8) & InstReg(3 downto 0));
    decodeASDIWConstant <= "00" & InstReg(7 downto 6) & InstReg(3 downto 0);

    decodeBitIndexB <= to_integer(unsigned(InstReg(2 downto 0)));
    decodeBitIndexS <= to_integer(unsigned(InstReg(6 downto 4)));

    

    -- Combinational logic that calculates the following:
    --   iau_ctrl: Controls what the next address that is fetched is.
    --   dau_ctrl: Controls what the data access unit is doing.
    --   reg_read_ctrl: Controls what is being read from register unit.
    --   ExecuteOpData: The op that is passed to execute stage.
    --   
    DecodeProc: process(SyncReset,
                        ProgABBuf,
                        ProgDBSync,
                        DataDB,
                        dau_update,
                        InstReg,
                        CurState,
                        reg_DataOutA,
                        reg_DataOutB,
                        reg_DataOutD,
                        reg_DataOutA_delay,
                        reg_DataOutB_delay,
                        alu_SReg,
                        decodeReg16d,
                        decodeReg32d,
                        decodeReg32r,
                        decodeDRegLow,
                        decodeDRegHigh,
                        decodeWordConstant,
                        decodeASDIWConstant,
                        decodeBitIndexB,
                        decodeBitIndexS)
        variable tmp_rd  : std_logic_vector(4 downto 0);
        variable tmp_rr  : std_logic_vector(4 downto 0);
    begin
        -- Minimum instructions needed to start testing:
        -- BCLR
        -- LDI
        -- ADD
        -- IN Rd, $3F  ; Read status register
        -- ST X, Rd

        -- Assign defaults
        -- Only the below assigned variables should be changed in this,
        -- to avoid implied latch
        iau_ctrl.srcSel <= IAU.SRC_PC; -- Start from current program counter
        iau_ctrl.OffsetSel <= IAU.OFF_ONE; -- Increment address by one
        dau_ctrl.SrcSel <= DAU.SRC_REG; -- Keep dau address the same
        dau_ctrl.OffsetSel <= DAU.OFF_ZERO; -- Leave dau address unchanged
        reg_read_ctrl.SelOutA <= (others => 'X');
        reg_read_ctrl.SelOutB <= (others => 'X');
        reg_read_ctrl.SelOutD <= (others => 'X');

        -- Default to executing a pass-through of OpA to result
        -- Done by adding OpA to OpB = 0, then making sure flags don't change.
        -- This makes passing data through to write unit easy.
        NextExecuteOpData.OpA <= (others => '0');
        NextExecuteOpData.OpB <= (others => '0');
        NextExecuteOpData.ALUOpCode <= ALUOp.ADD_Op;
        NextExecuteOpData.ALUFlagMask <= FlagMaskNone;
        NextExecuteOpData.writeRegEnS <= '0';
        NextExecuteOpData.writeRegSelS <= (others => '0');
        NextExecuteOpData.dataD <= dau_update;
        NextExecuteOpData.writeRegEnD <= '0';
        NextExecuteOpData.writeRegSelD <= (others => '0');
        DataDB <= (others => 'Z');
        startDataWr <= '1';
        startDataRd <= '1';

        DecodeUsedSreg <= '0';


        -- Control signal for previous pipeline stage
        LoadInstReg <= '1';
        LoadInstPayload <= '1';

        if SyncReset = '0' then
            -- Clear the status register
            iau_ctrl.srcSel <= IAU.SRC_ZERO;
            iau_ctrl.OffsetSel <= IAU.OFF_ZERO;
            NextExecuteOpData.OpA <= (others => '0');
            NextExecuteOpData.OpB <= (others => '1');
            NextExecuteOpData.ALUOpCode <= ALUOp.BCLR_Op;
            NextExecuteOpData.ALUFlagMask <= FlagMaskAll;
        else

            -- ALU
            if std_match(InstReg, Opcodes.OpNOP) then
                null;
            elsif std_match(InstReg, Opcodes.OpBCLR) then
                NextExecuteOpData.OpA <= alu_SReg;
                DecodeUsedSreg <= '1';
                NextExecuteOpData.OpB(decodeBitIndexS) <= '1';
                NextExecuteOpData.ALUFlagMask <= FlagMaskAll;
                NextExecuteOpData.ALUOpCode <= ALUOp.BCLR_Op;
            elsif std_match(InstReg, Opcodes.OpBSET) then
                NextExecuteOpData.OpA <= alu_SReg;
                DecodeUsedSreg <= '1';
                NextExecuteOpData.OpB(decodeBitIndexS) <= '1';
                NextExecuteOpData.ALUFlagMask <= FlagMaskAll;
                NextExecuteOpData.ALUOpCode <= ALUOp.BSET_Op;
            elsif std_match(InstReg, Opcodes.OpADD) then
                -- Decode register addresses
                tmp_rd := decodeReg32d;
                tmp_rr := decodeReg32r;
                reg_read_ctrl.SelOutA <= tmp_rd;
                reg_read_ctrl.SelOutB <= tmp_rr;
                -- Setup execute
                NextExecuteOpData.OpA <= reg_DataOutA;
                NextExecuteOpData.OpB <= reg_DataOutB;
                NextExecuteOpData.ALUOpCode <= ALUOp.ADD_Op;
                NextExecuteOpData.ALUFlagMask <= FlagMaskZCNVSH;
                -- Setup info for writeback
                NextExecuteOpData.writeRegEnS <= '1';
                NextExecuteOpData.writeRegSelS <= tmp_rd;
            elsif std_match(InstReg, Opcodes.OpADC) then
                tmp_rd := decodeReg32d;
                tmp_rr := decodeReg32r;
                reg_read_ctrl.SelOutA <= tmp_rd;
                reg_read_ctrl.SelOutB <= tmp_rr;
                NextExecuteOpData.OpA <= reg_DataOutA;
                NextExecuteOpData.OpB <= reg_DataOutB;
                NextExecuteOpData.ALUOpCode <= ALUOp.ADC_Op;
                NextExecuteOpData.ALUFlagMask <= FlagMaskZCNVSH;
                NextExecuteOpData.writeRegEnS <= '1';
                NextExecuteOpData.writeRegSelS <= tmp_rd;
            elsif std_match(InstReg, Opcodes.OpADIW) then
                -- ADIW takes 2 cycles:
                -- First, do an ADD with low register and immediate
                -- Next, do an ADC with high register and zero.
                if CurState = 0 then
                    -- Keep the instruction register the same
                    iau_ctrl.srcSel <= IAU.SRC_PC;
                    iau_ctrl.OffsetSel <= IAU.OFF_ZERO;
                    LoadInstReg <= '0';
                    -- Do an ADD low register in double register, immediate K
                    tmp_rd := decodeDRegLow;
                    reg_read_ctrl.SelOutA <= tmp_rd;
                    NextExecuteOpData.OpA <= reg_DataOutA;
                    -- Set immediate value bits. Default to 0, see above default conds.
                    NextExecuteOpData.OpB <= decodeASDIWConstant;
                    NextExecuteOpData.ALUOpCode <= ALUOp.ADD_Op;
                    NextExecuteOpData.ALUFlagMask <= FlagMaskZCNVS;
                    NextExecuteOpData.writeRegEnS <= '1';
                    NextExecuteOpData.writeRegSelS <= tmp_rd;
                else
                    -- Do an ADC high register in double register, 0
                    -- This carries the carry from low add into high register
                    tmp_rd := decodeDRegHigh;
                    reg_read_ctrl.SelOutA <= tmp_rd;
                    NextExecuteOpData.OpA <= reg_DataOutA;
                    -- Set to 0 by default statements above, but be explicit about it:
                    NextExecuteOpData.OpB <= (others => '0');
                    NextExecuteOpData.ALUOpCode <= ALUOp.ADC_Op;
                    DecodeUsedSreg <= '1';
                    if alu_SReg(AVR.STATUS_ZERO) = '0' then
                        -- If the low register was not zero, the result is not zero,
                        -- so leave zero flag unset.
                        NextExecuteOpData.ALUFlagMask <= FlagMaskCNVS;
                    else 
                        NextExecuteOpData.ALUFlagMask <= FlagMaskZCNVS;
                    end if;
                    NextExecuteOpData.writeRegEnS <= '1';
                    NextExecuteOpData.writeRegSelS <= tmp_rd;
                end if;
            elsif (std_match(InstReg, Opcodes.OpAND) or
                   std_match(InstReg, Opcodes.OpANDI)) then
                -- Common to both AND and ANDI
                
                NextExecuteOpData.ALUOpCode <= ALUOp.AND_Op;
                NextExecuteOpData.ALUFlagMask <= FlagMaskZNVS;
                if std_match(InstReg, Opcodes.OpAND) then
                    -- Opcode is OpAND
                    tmp_rd := decodeReg32d;
                    reg_read_ctrl.SelOutA <= tmp_rd;
                    NextExecuteOpData.OpA <= reg_DataOutA;
                    tmp_rr := decodeReg32r;
                    reg_read_ctrl.SelOutB <= tmp_rr;
                    NextExecuteOpData.OpB <= reg_DataOutB;
                else
                    -- Opcode is OpANDI
                    tmp_rd := decodeReg16d;
                    reg_read_ctrl.SelOutA <= tmp_rd;
                    NextExecuteOpData.OpA <= reg_DataOutA;
                    NextExecuteOpData.OpB <= decodeWordConstant;
                end if;
                NextExecuteOpData.writeRegEnS <= '1';
                NextExecuteOpData.writeRegSelS <= tmp_rd;
            elsif std_match(Instreg, Opcodes.OpASR) then
                tmp_rd := decodeReg32d;
                reg_read_ctrl.SelOutA <= tmp_rd;
                NextExecuteOpData.OpA <= reg_DataOutA;
                NextExecuteOpData.ALUOpCode <= ALUOp.ASR_Op;
                NextExecuteOpData.ALUFlagMask <= FlagMaskZCNVS;
                NextExecuteOpData.writeRegEnS <= '1';
                NextExecuteOpData.writeRegSelS <= tmp_rd;
            elsif std_match(Instreg, Opcodes.OpBLD) then
                DecodeUsedSreg <= '1';
                tmp_rd := decodeReg32d;
                reg_read_ctrl.SelOutA <= tmp_rd;
                NextExecuteOpData.OpA <= reg_DataOutA;
                NextExecuteOpData.OpA <= reg_DataOutA;
                NextExecuteOpData.OpB(decodeBitIndexB) <= (reg_DataOutA(decodeBitIndexB) xor alu_SReg(AVR.STATUS_TRANS));
                NextExecuteOpData.ALUOpCode <= ALUOp.EOR_Op;
                NextExecuteOpData.ALUFlagMask <= FlagMaskNone;
                NextExecuteOpData.writeRegEnS <= '1';
                NextExecuteOpData.writeRegSelS <= tmp_rd;
            elsif std_match(Instreg, Opcodes.OpBST) then
                -- BST Rd, b
                -- Set the SREG T flag to the bit at decodeBitIndexB in Rd
                -- Do this by using the ALUOp.BSET_Op with the single bit from
                -- Rd assigned to the T slot in OpA, and then only update the
                -- T position of SREG using flag mask
                tmp_rd := decodeReg32d;
                reg_read_ctrl.SelOutA <= tmp_rd;
                NextExecuteOpData.OpA <= (others => reg_DataOutA(decodeBitIndexB));
                NextExecuteOpData.ALUOpCode <= ALUOp.BSET_Op;
                NextExecuteOpData.ALUFlagMask <= FlagMaskT;
            elsif std_match(InstReg, Opcodes.OpCOM) then
                tmp_rd := decodeReg32d;
                reg_read_ctrl.SelOutA <= tmp_rd;
                NextExecuteOpData.OpA <= reg_DataOutA;
                NextExecuteOpData.ALUOpCode <= ALUOp.COM_Op;
                NextExecuteOpData.ALUFlagMask <= FlagMaskZCNVS;
                NextExecuteOpData.writeRegEnS <= '1';
                NextExecuteOpData.writeRegSelS <= tmp_rd;
            elsif std_match(InstReg, Opcodes.OpCP) then
                -- Compare Rd and Rr by doing subtraction
                -- but not storing result
                tmp_rd := decodeReg32d;
                tmp_rr := decodeReg32r;
                reg_read_ctrl.SelOutA <= tmp_rd;
                reg_read_ctrl.SelOutB <= tmp_rr;
                NextExecuteOpData.OpA <= reg_DataOutA;
                NextExecuteOpData.OpB <= reg_DataOutB;
                NextExecuteOpData.ALUOpCode <= ALUOp.SUB_Op;
                NextExecuteOpData.ALUFlagMask <= FlagMaskZCNVSH;
                -- No writeback of result
            elsif std_match(InstReg, Opcodes.OpCPC) then
                -- Compare with carry Rd and Rr by doing subtraction
                -- with carry but not storing result
                tmp_rd := decodeReg32d;
                tmp_rr := decodeReg32r;
                reg_read_ctrl.SelOutA <= tmp_rd;
                reg_read_ctrl.SelOutB <= tmp_rr;
                NextExecuteOpData.OpA <= reg_DataOutA;
                NextExecuteOpData.OpB <= reg_DataOutB;
                NextExecuteOpData.ALUOpCode <= ALUOp.SBC_Op;
                NextExecuteOpData.ALUFlagMask <= FlagMaskZCNVSH;
                -- No writeback of result
            elsif std_match(InstReg, Opcodes.OpCPI) then
                -- Compare Rd and immediate by doing subtraction
                -- but not storing result
                tmp_rd := decodeReg16d;
                reg_read_ctrl.SelOutA <= tmp_rd;
                NextExecuteOpData.OpA <= reg_DataOutA;
                NextExecuteOpData.OpB <= decodeWordConstant;
                NextExecuteOpData.ALUOpCode <= ALUOp.SUB_Op;
                NextExecuteOpData.ALUFlagMask <= FlagMaskZCNVSH;
                -- No writeback of result
            elsif std_match(InstReg, Opcodes.OpDEC) then
                -- Subtract Rd by immediate value of 1
                tmp_rd := decodeReg32d;
                reg_read_ctrl.SelOutA <= tmp_rd;
                NextExecuteOpData.OpA <= reg_DataOutA;
                NextExecuteOpData.OpB <= "00000001"; -- Subtract 1
                NextExecuteOpData.ALUOpCode <= ALUOp.SUB_Op;
                NextExecuteOpData.ALUFlagMask <= FlagMaskZNVS;
                NextExecuteOpData.writeRegEnS <= '1';
                NextExecuteOpData.writeRegSelS <= tmp_rd;
            elsif std_match(InstReg, Opcodes.OpEOR) then
                -- Compute XOR of Rd and Rr, and store back in Rd
                tmp_rd := decodeReg32d;
                tmp_rr := decodeReg32r;
                reg_read_ctrl.SelOutA <= tmp_rd;
                reg_read_ctrl.SelOutB <= tmp_rr;
                NextExecuteOpData.OpA <= reg_DataOutA;
                NextExecuteOpData.OpB <= reg_DataOutB;
                NextExecuteOpData.ALUOpCode <= ALUOp.EOR_Op;
                NextExecuteOpData.ALUFlagMask <= FlagMaskZNVS;
                NextExecuteOpData.writeRegEnS <= '1';
                NextExecuteOpData.writeRegSelS <= tmp_rd;
            elsif std_match(InstReg, Opcodes.OpINC) then
                -- Increment Rd by adding an immediate value of 1
                tmp_rd := decodeReg32d;
                reg_read_ctrl.SelOutA <= tmp_rd;
                NextExecuteOpData.OpA <= reg_DataOutA;
                NextExecuteOpData.OpB <= "00000001"; -- Add 1
                NextExecuteOpData.ALUOpCode <= ALUOp.ADD_Op;
                NextExecuteOpData.ALUFlagMask <= FlagMaskZNVS;
                NextExecuteOpData.writeRegEnS <= '1';
                NextExecuteOpData.writeRegSelS <= tmp_rd;
            elsif std_match(InstReg, Opcodes.OpINC) then
                -- Increment Rd by adding an immediate value of 1
                tmp_rd := decodeReg32d;
                reg_read_ctrl.SelOutA <= tmp_rd;
                NextExecuteOpData.OpA <= reg_DataOutA;
                NextExecuteOpData.OpB <= "00000001"; -- Add 1
                NextExecuteOpData.ALUOpCode <= ALUOp.ADD_Op;
                NextExecuteOpData.ALUFlagMask <= FlagMaskZNVS;
                NextExecuteOpData.writeRegEnS <= '1';
                NextExecuteOpData.writeRegSelS <= tmp_rd;
            elsif std_match(Instreg, Opcodes.OpLSR) then
                tmp_rd := decodeReg32d;
                reg_read_ctrl.SelOutA <= tmp_rd;
                NextExecuteOpData.OpA <= reg_DataOutA;
                NextExecuteOpData.ALUOpCode <= ALUOp.LSR_Op;
                NextExecuteOpData.ALUFlagMask <= FlagMaskZCNVS;
                NextExecuteOpData.writeRegEnS <= '1';
                NextExecuteOpData.writeRegSelS <= tmp_rd;
            elsif std_match(Instreg, Opcodes.OpNEG) then
                tmp_rd := decodeReg32d;
                reg_read_ctrl.SelOutB <= tmp_rd;
                NextExecuteOpData.OpB <= reg_DataOutB;
                NextExecuteOpData.ALUOpCode <= ALUOp.SUB_Op;
                NextExecuteOpData.ALUFlagMask <= FlagMaskZCNVSH;
                NextExecuteOpData.writeRegEnS <= '1';
                NextExecuteOpData.writeRegSelS <= tmp_rd;
            elsif (std_match(InstReg, Opcodes.OpOR) or
                   std_match(InstReg, Opcodes.OpORI)) then
                -- Common to both OR and ORI
                NextExecuteOpData.ALUOpCode <= ALUOp.OR_Op;
                NextExecuteOpData.ALUFlagMask <= FlagMaskZNVS;
                if std_match(InstReg, Opcodes.OpOR) then
                    -- Opcode is OpOR
                    tmp_rd := decodeReg32d;
                    reg_read_ctrl.SelOutA <= tmp_rd;
                    NextExecuteOpData.OpA <= reg_DataOutA;
                    tmp_rr := decodeReg32r;
                    reg_read_ctrl.SelOutB <= tmp_rr;
                    NextExecuteOpData.OpB <= reg_DataOutB;
                else
                    -- Opcode is OpORI
                    tmp_rd := decodeReg16d;
                    reg_read_ctrl.SelOutA <= tmp_rd;
                    NextExecuteOpData.OpA <= reg_DataOutA;
                    NextExecuteOpData.OpB <= decodeWordConstant;
                end if;
                NextExecuteOpData.writeRegEnS <= '1';
                NextExecuteOpData.writeRegSelS <= tmp_rd;
            elsif std_match(Instreg, Opcodes.OpROR) then
                tmp_rd := decodeReg32d;
                reg_read_ctrl.SelOutA <= tmp_rd;
                NextExecuteOpData.OpA <= reg_DataOutA;
                NextExecuteOpData.ALUOpCode <= ALUOp.ROR_Op;
                NextExecuteOpData.ALUFlagMask <= FlagMaskZCNVS;
                NextExecuteOpData.writeRegEnS <= '1';
                NextExecuteOpData.writeRegSelS <= tmp_rd;
            elsif std_match(InstReg, Opcodes.OpSBC) then
                tmp_rd := decodeReg32d;
                tmp_rr := decodeReg32r;
                reg_read_ctrl.SelOutA <= tmp_rd;
                reg_read_ctrl.SelOutB <= tmp_rr;
                NextExecuteOpData.OpA <= reg_DataOutA;
                NextExecuteOpData.OpB <= reg_DataOutB;
                NextExecuteOpData.ALUOpCode <= ALUOp.SBC_Op;
                DecodeUsedSreg <= '1';
                -- Implement special behavior for zero flag for SBC
                -- If the previous result is zero, then update flag
                -- Otherwise, don't update, therefore leaving flag at 0.
                if alu_SReg(AVR.STATUS_ZERO) = '1' then
                    NextExecuteOpData.ALUFlagMask <= FlagMaskZCNVSH;
                else
                    NextExecuteOpData.ALUFlagMask <= FlagMaskCNVSH;
                end if;
                NextExecuteOpData.writeRegEnS <= '1';
                NextExecuteOpData.writeRegSelS <= tmp_rd;
            elsif std_match(InstReg, Opcodes.OpSBCI) then
                tmp_rd := decodeReg16d;
                reg_read_ctrl.SelOutA <= tmp_rd;
                NextExecuteOpData.OpA <= reg_DataOutA;
                NextExecuteOpData.OpB <= decodeWordConstant;
                NextExecuteOpData.ALUOpCode <= ALUOp.SBC_Op;
                DecodeUsedSreg <= '1';
                -- Implement special behavior for zero flag for SBC
                -- If the previous result is zero, then update flag
                -- Otherwise, don't update, therefore leaving flag at 0.
                if alu_SReg(AVR.STATUS_ZERO) = '1' then
                    NextExecuteOpData.ALUFlagMask <= FlagMaskZCNVSH;
                else
                    NextExecuteOpData.ALUFlagMask <= FlagMaskCNVSH;
                end if;
                NextExecuteOpData.writeRegEnS <= '1';
                NextExecuteOpData.writeRegSelS <= tmp_rd;
            elsif std_match(InstReg, Opcodes.OpSBIW) then
                -- SBIW takes 2 cycles:
                -- First, do a SUB with low register and immediate
                -- Next, do an SBC with high register and zero.
                if CurState = 0 then
                    -- Keep the instruction register the same
                    iau_ctrl.srcSel <= IAU.SRC_PC;
                    iau_ctrl.OffsetSel <= IAU.OFF_ZERO;
                    LoadInstReg <= '0';
                    -- Do an ADD low register in double register, immediate K
                    tmp_rd := decodeDRegLow;
                    reg_read_ctrl.SelOutA <= tmp_rd;
                    NextExecuteOpData.OpA <= reg_DataOutA;
                    -- Set immediate value bits. Default to 0, see above default conds.
                    NextExecuteOpData.OpB <= decodeASDIWConstant;
                    NextExecuteOpData.ALUOpCode <= ALUOp.SUB_Op;
                    NextExecuteOpData.ALUFlagMask <= FlagMaskZCNVS;
                    NextExecuteOpData.writeRegEnS <= '1';
                    NextExecuteOpData.writeRegSelS <= tmp_rd;
                else
                    -- Do an ADC high register in double register, 0
                    -- This carries the carry from low add into high register
                    tmp_rd := decodeDRegHigh;
                    reg_read_ctrl.SelOutA <= tmp_rd;
                    NextExecuteOpData.OpA <= reg_DataOutA;
                    -- Set to 0 by default statements above, but be explicit about it:
                    NextExecuteOpData.OpB <= (others => '0');
                    NextExecuteOpData.ALUOpCode <= ALUOp.SBC_Op;
                    DecodeUsedSreg <= '1';
                    if alu_SReg(AVR.STATUS_ZERO) = '0' then
                        -- If the low register was not zero, the result is not zero,
                        -- so leave zero flag unset.
                        NextExecuteOpData.ALUFlagMask <= FlagMaskCNVS;
                    else 
                        NextExecuteOpData.ALUFlagMask <= FlagMaskZCNVS;
                    end if;
                    NextExecuteOpData.writeRegEnS <= '1';
                    NextExecuteOpData.writeRegSelS <= tmp_rd;
                end if;
            elsif std_match(InstReg, Opcodes.OpSUB) then
                tmp_rd := decodeReg32d;
                tmp_rr := decodeReg32r;
                reg_read_ctrl.SelOutA <= tmp_rd;
                reg_read_ctrl.SelOutB <= tmp_rr;
                NextExecuteOpData.OpA <= reg_DataOutA;
                NextExecuteOpData.OpB <= reg_DataOutB;
                NextExecuteOpData.ALUOpCode <= ALUOp.SUB_Op;
                NextExecuteOpData.ALUFlagMask <= FlagMaskZCNVSH;
                NextExecuteOpData.writeRegEnS <= '1';
                NextExecuteOpData.writeRegSelS <= tmp_rd;
            elsif std_match(InstReg, Opcodes.OpSUBI) then
                tmp_rd := decodeReg16d;
                reg_read_ctrl.SelOutA <= tmp_rd;
                NextExecuteOpData.OpA <= reg_DataOutA;
                NextExecuteOpData.OpB <= decodeWordConstant;
                NextExecuteOpData.ALUOpCode <= ALUOp.SUB_Op;
                NextExecuteOpData.ALUFlagMask <= FlagMaskZCNVSH;
                NextExecuteOpData.writeRegEnS <= '1';
                NextExecuteOpData.writeRegSelS <= tmp_rd;
            elsif std_match(InstReg, Opcodes.OpSWAP) then
                -- Swap low and high nibbles of Rd
                tmp_rd := decodeReg32d;
                reg_read_ctrl.SelOutA <= tmp_rd;
                NextExecuteOpData.OpA <= reg_DataOutA;
                NextExecuteOpData.ALUOpCode <= ALUOp.SWAP_Op;
                NextExecuteOpData.ALUFlagMask <= FlagMaskNone;
                NextExecuteOpData.writeRegEnS <= '1';
                NextExecuteOpData.writeRegSelS <= tmp_rd;
            elsif std_match(InstReg, Opcodes.OpMUL) then
                -- MUL takes 2 cycles:
                -- First, do a MULL
                -- Next, do a MULH
                tmp_rd := decodeReg32d;
                tmp_rr := decodeReg32r;
                reg_read_ctrl.SelOutA <= tmp_rd;
                reg_read_ctrl.SelOutB <= tmp_rr;
                if CurState = 0 then
                    -- Keep the instruction register the same
                    iau_ctrl.srcSel <= IAU.SRC_PC;
                    iau_ctrl.OffsetSel <= IAU.OFF_ZERO;
                    LoadInstReg <= '0';
                    -- Do a MULL with Rd and Rr
                    NextExecuteOpData.OpA <= reg_DataOutA;
                    NextExecuteOpData.OpB <= reg_DataOutB;
                    NextExecuteOpData.ALUOpCode <= ALUOp.MULL_Op;
                    NextExecuteOpData.ALUFlagMask <= FlagMaskZC;
                    NextExecuteOpData.writeRegEnS <= '1';
                    -- MUL writes back low byte to r0 always
                    NextExecuteOpData.writeRegSelS <= "00000";
                else
                    -- Do a MULH with Rd and Rr
                    -- To get around issue with ALU implementation
                    -- of MUL that is fully combinational,
                    -- we have a register-delayed output
                    -- that we mux in instead. This is needed
                    -- for the case when one of the operands is
                    -- r0 or r1.
                    NextExecuteOpData.OpA <= reg_DataOutA_delay;
                    NextExecuteOpData.OpB <= reg_DataOutB_delay;
                    NextExecuteOpData.ALUOpCode <= ALUOp.MULH_Op;
                    NextExecuteOpData.ALUFlagMask <= FlagMaskZC;
                    NextExecuteOpData.writeRegEnS <= '1';
                    -- MUL writes back high byte to r1 always
                    NextExecuteOpData.writeRegSelS <= "00001";
                end if;
            -------------------
            -------------------
            -- Skip Instructions
            -------------------
            -------------------
            elsif std_match(InstReg, Opcodes.OpCPSE) then
                -- Compare Rd and Rr by doing subtraction
                -- but not storing result
                if CurState = 0 then
                    tmp_rd := decodeReg32d;
                    tmp_rr := decodeReg32r;
                    reg_read_ctrl.SelOutA <= tmp_rd;
                    reg_read_ctrl.SelOutB <= tmp_rr;
                    if reg_DataOutA = reg_DataOutB then
                        LoadInstReg <= '0';
                    else
                        LoadInstReg <= '1';
                    end if;
                elsif CurState = 1 then
                    -- We are at first word of skipped instruction.
                    -- Check if this is a two-word instruction
                    -- TODO(WHW): This is examining the next instruction,
                    -- not current instruction registered, 
                    if (std_match(ProgDBSync, Opcodes.OpLDS) or
                        std_match(ProgDBSync, Opcodes.OpSTS) or
                        std_match(ProgDBSync, Opcodes.OpJMP) or
                        std_match(ProgDBSync, Opcodes.OpCALL)) then
                        LoadInstReg <= '0';
                    else
                        LoadInstReg <= '1';
                    end if;
                else
                    null;
                    -- CurState is 2.
                    -- All instructions are at most 2 words,
                    -- so always continue to next instruction now.
                end if;
            elsif std_match(InstReg, Opcodes.OpSBRC) then
                -- Compare Rd and Rr by doing subtraction
                -- but not storing result
                if CurState = 0 then
                    tmp_rd := decodeReg32d;
                    reg_read_ctrl.SelOutA <= tmp_rd;
                    if reg_DataOutA(decodeBitIndexB) = '0' then
                        LoadInstReg <= '0';
                    else
                        LoadInstReg <= '1';
                    end if;
                elsif CurState = 1 then
                    -- We are at first word of skipped instruction.
                    -- Check if this is a two-word instruction
                    -- TODO(WHW): This is examining the next instruction,
                    -- not current instruction registered, 
                    if (std_match(ProgDBSync, Opcodes.OpLDS) or
                        std_match(ProgDBSync, Opcodes.OpSTS) or
                        std_match(ProgDBSync, Opcodes.OpJMP) or
                        std_match(ProgDBSync, Opcodes.OpCALL)) then
                        LoadInstReg <= '0';
                    else
                        LoadInstReg <= '1';
                    end if;
                else
                    null;
                    -- CurState is 2.
                    -- All instructions are at most 2 words,
                    -- so always continue to next instruction now.
                end if;
            elsif std_match(InstReg, Opcodes.OpSBRS) then
                -- Compare Rd and Rr by doing subtraction
                -- but not storing result
                if CurState = 0 then
                    tmp_rd := decodeReg32d;
                    reg_read_ctrl.SelOutA <= tmp_rd;
                    if reg_DataOutA(decodeBitIndexB) = '1' then
                        LoadInstReg <= '0';
                    else
                        LoadInstReg <= '1';
                    end if;
                elsif CurState = 1 then
                    -- We are at first word of skipped instruction.
                    -- Check if this is a two-word instruction
                    -- TODO(WHW): This is examining the next instruction,
                    -- not current instruction registered, 
                    if (std_match(ProgDBSync, Opcodes.OpLDS) or
                        std_match(ProgDBSync, Opcodes.OpSTS) or
                        std_match(ProgDBSync, Opcodes.OpJMP) or
                        std_match(ProgDBSync, Opcodes.OpCALL)) then
                        LoadInstReg <= '0';
                    else
                        LoadInstReg <= '1';
                    end if;
                else
                    null;
                    -- CurState is 2.
                    -- All instructions are at most 2 words,
                    -- so always continue to next instruction now.
                end if;
            -------------------
            -------------------
            -- Conditional Branch
            -------------------
            -------------------
            elsif std_match(InstReg, Opcodes.OpBRBC) then
                DecodeUsedSreg <= '1';
                -- If the bit is cleared, then take branch.
                -- Otherwise, keep default which is to just go to next
                -- instruction.
                if CurState = 0 and alu_Sreg(decodeBitIndexB) = '0' then
                    iau_ctrl.OffsetSel <= IAU.OFF_BRANCH;
                    LoadInstReg <= '0';
                end if;
            elsif std_match(InstReg, Opcodes.OpBRBS) then
                DecodeUsedSreg <= '1';
                -- If the bit is set, then take branch.
                -- Otherwise, keep default which is to just go to next
                -- instruction.
                if CurState = 0 and alu_Sreg(decodeBitIndexB) = '1' then
                    iau_ctrl.OffsetSel <= IAU.OFF_BRANCH;
                    LoadInstReg <= '0';
                end if;
            -------------------
            -------------------
            -- Unconditional Branch (Jumps)
            -------------------
            -------------------
            elsif std_match(InstReg, Opcodes.OpJMP) then
                if CurState = 0 then
                    -- Load the memory address
                    
                    LoadInstReg <= '0';
                -- not sure why this takes three cycles
                elsif CurState = 1 then
                    iau_ctrl.srcSel <= IAU.SRC_ZERO;
                    iau_ctrl.offsetSel <= IAU.OFF_PDB;
                    LoadInstReg <= '0';
                    LoadInstPayload <= '0';
                elsif CurState = 2 then
                    iau_ctrl.offsetSel <= IAU.OFF_ZERO;
                end if;
            elsif std_match(InstReg, Opcodes.OpRJMP) then
                if CurState = 0 then
                    -- Increment by 1 here, it will load an
                    -- irrelevant instruction, but simplifies
                    -- the generation of pc+k+1 on next cycle.
                    iau_ctrl.offsetSel <= IAU.OFF_ONE;
                    LoadInstReg <= '0';
                    LoadInstPayload <= '0';
                elsif CurState = 1 then
                    iau_ctrl.offsetSel <= IAU.OFF_JUMP;
                end if;
            elsif std_match(InstReg, Opcodes.OpIJMP) then
                reg_read_ctrl.SelOutD <= "11";
                if CurState = 0 then
                    iau_ctrl.offsetSel <= IAU.OFF_ZERO;
                    LoadInstReg <= '0';
                elsif CurState = 1 then
                    iau_ctrl.srcSel <= IAU.SRC_ZERO;
                    iau_ctrl.offsetSel <= IAU.OFF_Z;
                end if;
            -------------------
            -------------------
            -- Unconditional Branch (Calls and Returns)
            -------------------
            -------------------
            elsif std_match(InstReg, Opcodes.OpCall) then
                if CurState = 0 then
                    -- Steps on Cycle 0 (ProgAB is PC+1):
                    -- Identify call instruction (implicit by being in this if)
                    -- Set InstReg to persist
                    -- Set InstPayload to load on next clock
                    -- Leave IAU to increment, so next clock will be PC+2
                    LoadInstReg <= '0';
                elsif CurState = 1 then
                    -- Steps on Cycle 1 (ProgAB is PC+2):
                    -- Set IAU to hold pc in place
                    -- Write PC+2[15:8] to stack
                    -- InstPayload is loaded as target address
                    LoadInstReg <= '0';
                    LoadInstPayload <= '0';
                    iau_ctrl.srcSel <= IAU.SRC_PC;
                    iau_ctrl.offsetSel <= IAU.OFF_ONE;
                    DataDB <= ProgABBuf(15 downto 8);
                    dau_ctrl.SrcSel <= DAU.SRC_STACK;
                    dau_ctrl.OffsetSel <= DAU.OFF_NEGONE;
                    startDataWr <= '0';
                elsif CurState = 2 then
                    -- Steps on Cycle 2 (ProgAB is PC+2):
                    -- Write PC+2[7:0] to stack
                    -- Set IAU to update pc to target address
                    LoadInstReg <= '0';
                    LoadInstPayload <= '0';
                    iau_ctrl.srcSel <= IAU.SRC_PC;
                    iau_ctrl.offsetSel <= IAU.OFF_ZERO;
                    DataDB <= ProgABBuf(7 downto 0);
                    dau_ctrl.SrcSel <= DAU.SRC_STACK;
                    dau_ctrl.OffsetSel <= DAU.OFF_NEGONE;
                    startDataWr <= '0';
                else -- CurState = 3
                    iau_ctrl.srcSel <= IAU.SRC_ZERO;
                    iau_ctrl.offsetSel <= IAU.OFF_PDB;
                end if;
            elsif std_match(InstReg, Opcodes.OpRCall) then
                if CurState = 0 then
                    LoadInstReg <= '0';
                    LoadInstPayload <= '0';
                    iau_ctrl.srcSel <= IAU.SRC_PC;
                    iau_ctrl.offsetSel <= IAU.OFF_ONE;
                    DataDB <= ProgABBuf(15 downto 8);
                    dau_ctrl.SrcSel <= DAU.SRC_STACK;
                    dau_ctrl.OffsetSel <= DAU.OFF_NEGONE;
                    startDataWr <= '0';
                elsif CurState = 1 then
                    LoadInstReg <= '0';
                    LoadInstPayload <= '0';
                    iau_ctrl.srcSel <= IAU.SRC_PC;
                    iau_ctrl.offsetSel <= IAU.OFF_ZERO;
                    DataDB <= ProgABBuf(7 downto 0);
                    dau_ctrl.SrcSel <= DAU.SRC_STACK;
                    dau_ctrl.OffsetSel <= DAU.OFF_NEGONE;
                    startDataWr <= '0';
                    
                elsif CurState = 2 then
                    iau_ctrl.offsetSel <= IAU.OFF_JUMP;                    
                end if;
            elsif std_match(InstReg, Opcodes.OpICall) then
                reg_read_ctrl.SelOutD <= "11";
                if CurState = 0 then
                    LoadInstReg <= '0';
                    LoadInstPayload <= '0';
                    iau_ctrl.srcSel <= IAU.SRC_PC;
                    iau_ctrl.offsetSel <= IAU.OFF_ONE;
                    DataDB <= ProgABBuf(15 downto 8);
                    dau_ctrl.SrcSel <= DAU.SRC_STACK;
                    dau_ctrl.OffsetSel <= DAU.OFF_NEGONE;
                    startDataWr <= '0';
                elsif CurState = 1 then
                    LoadInstReg <= '0';
                    LoadInstPayload <= '0';
                    iau_ctrl.srcSel <= IAU.SRC_PC;
                    iau_ctrl.offsetSel <= IAU.OFF_ZERO;
                    DataDB <= ProgABBuf(7 downto 0);
                    dau_ctrl.SrcSel <= DAU.SRC_STACK;
                    dau_ctrl.OffsetSel <= DAU.OFF_NEGONE;
                    startDataWr <= '0';
                elsif CurState = 2 then
                    iau_ctrl.srcSel <= IAU.SRC_ZERO;
                    iau_ctrl.offsetSel <= IAU.OFF_Z;
                end if;
            elsif std_match(InstReg, Opcodes.OpRET) then
                if CurState = 0 then
                    LoadInstReg <= '0';
                elsif CurState = 1 then
                    LoadInstReg <= '0';
                    iau_ctrl.srcSel <= IAU.SRC_ZERO;
                    iau_ctrl.offsetSel <= IAU.OFF_DDBLO;
                    dau_ctrl.SrcSel <= DAU.SRC_STACK;
                    dau_ctrl.OffsetSel <= DAU.OFF_ONE;
                    startDataRd <= '0';
                elsif CurState = 2 then
                    LoadInstReg <= '0';
                    iau_ctrl.srcSel <= IAU.SRC_PC;
                    iau_ctrl.offsetSel <= IAU.OFF_DDBHI;
                    dau_ctrl.SrcSel <= DAU.SRC_STACK;
                    dau_ctrl.OffsetSel <= DAU.OFF_ONE;
                    startDataRd <= '0';
                else -- CurState = 3
                    iau_ctrl.offsetSel <= IAU.OFF_ZERO;
                end if;
            elsif std_match(InstReg, Opcodes.OpRETI) then
                if CurState = 0 then
                    DecodeUsedSreg <= '1';
                    NextExecuteOpData.OpA <= alu_SReg;
                    NextExecuteOpData.OpB(AVR.STATUS_INT) <= '1';
                    NextExecuteOpData.ALUFlagMask <= FlagMaskAll;
                    NextExecuteOpData.ALUOpCode <= ALUOp.BSET_Op;
                    LoadInstReg <= '0';
                elsif CurState = 1 then
                    LoadInstReg <= '0';
                    iau_ctrl.srcSel <= IAU.SRC_ZERO;
                    iau_ctrl.offsetSel <= IAU.OFF_DDBLO;
                    dau_ctrl.SrcSel <= DAU.SRC_STACK;
                    dau_ctrl.OffsetSel <= DAU.OFF_ONE;
                    startDataRd <= '0';
                elsif CurState = 2 then
                    LoadInstReg <= '0';
                    iau_ctrl.srcSel <= IAU.SRC_PC;
                    iau_ctrl.offsetSel <= IAU.OFF_DDBHI;
                    dau_ctrl.SrcSel <= DAU.SRC_STACK;
                    dau_ctrl.OffsetSel <= DAU.OFF_ONE;
                    startDataRd <= '0';
                else -- CurState = 3
                    iau_ctrl.offsetSel <= IAU.OFF_ZERO;
                end if;
            -------------------
            -------------------
            -- LOAD/STORE Instructions
            -------------------
            -------------------
            elsif std_match(InstReg, Opcodes.OpIN) then
                -- Fixed IN Rd, $3F  ; Copies status register to Rd
                DecodeUsedSreg <= '1';
                NextExecuteOpData.writeRegEnS <= '1';
                NextExecuteOpData.writeRegSelS <= decodeReg32d;
                NextExecuteOpData.OpA <= alu_SReg;
            elsif std_match(InstReg, Opcodes.OpOut) then
                -- Fixed OUT $3F, Rr  ; Outputs Rr to the status register
                -- BSET instruction is Sreg = A or B. By default, B is zeros.
                reg_read_ctrl.SelOutA <= decodeReg32d;
                NextExecuteOpData.OpA <= reg_DataOutA;
                if (InstReg(10 downto 9) & InstReg(3 downto 0)) = "111111" then
                    -- The target for output is the status register
                    -- Load the register into status register
                    NextExecuteOpData.ALUOpCode <= ALUOp.BSET_Op;
                    NextExecuteOpData.ALUFlagMask <= FlagMaskAll;
                end if;
                NextExecuteOpData.writeRegEnS <= '0';
            elsif std_match(InstReg, Opcodes.OpMOV) then
                reg_read_ctrl.SelOutA <= decodeReg32r;
                NextExecuteOpData.OpA <= reg_DataOutA;
                NextExecuteOpData.writeRegEnS <= '1';
                NextExecuteOpData.writeRegSelS <= decodeReg32d;
            elsif (std_match(InstReg, Opcodes.OpLD) 
                    or std_match(Instreg, Opcodes.OpLDY)
                    or std_match(InstReg, Opcodes.OpLDZ))
                    and not(std_match(InstReg, Opcodes.OpLDS)
                    or std_match(InstReg, Opcodes.OpPOP))
            then
                -- Two cycle data read instructions:
                -- Cycle 0:
                --   - Setup data bus address and data
                --   - Halt ProgAB updates
                -- Cycle 1:
                --   - Do read cycle
                --   - Increment to next instruction
                if CurState = 0 then
                    iau_ctrl.OffsetSel <= IAU.OFF_ZERO;
                    LoadInstReg <= '0';
                elsif CurState = 1 then
                    startDataRd <= '0';
                    NextExecuteOpData.OpA <= DataDB;
                    NextExecuteOpData.writeRegEnS <= '1';
                    NextExecuteOpData.writeRegSelS <= decodeReg32d;
                    NextExecuteOpData.writeRegEnD <= '1';
                end if;
                if std_match(InstReg, Opcodes.OpLDX) then
                    reg_read_ctrl.SelOutD <= "01";
                    dau_ctrl.OffsetSel <= DAU.OFF_ZERO;
                    NextExecuteOpData.writeRegSelD <= "01";
                elsif std_match(InstReg, Opcodes.OpLDXI) then
                    reg_read_ctrl.SelOutD <= "01";
                    dau_ctrl.OffsetSel <= DAU.OFF_ONE;
                    NextExecuteOpData.writeRegSelD <= "01";
                elsif std_match(InstReg, Opcodes.OpLDXD) then
                    reg_read_ctrl.SelOutD <= "01";
                    dau_ctrl.OffsetSel <= DAU.OFF_NEGONE;
                    NextExecuteOpData.writeRegSelD <= "01";
                elsif std_match(InstReg, Opcodes.OpLDY) then
                    reg_read_ctrl.SelOutD <= "10";
                    dau_ctrl.OffsetSel <= DAU.OFF_ZERO;
                    NextExecuteOpData.writeRegSelD <= "10";
                elsif std_match(InstReg, Opcodes.OpLDYI) then
                    reg_read_ctrl.SelOutD <= "10";
                    dau_ctrl.OffsetSel <= DAU.OFF_ONE;
                    NextExecuteOpData.writeRegSelD <= "10";
                elsif std_match(InstReg, Opcodes.OpLDYD) then
                    reg_read_ctrl.SelOutD <= "10";
                    dau_ctrl.OffsetSel <= DAU.OFF_NEGONE;
                    NextExecuteOpData.writeRegSelD <= "10";
                elsif std_match(InstReg, Opcodes.OpLDZ) then
                    reg_read_ctrl.SelOutD <= "11";
                    dau_ctrl.OffsetSel <= DAU.OFF_ZERO;
                    NextExecuteOpData.writeRegSelD <= "11";
                elsif std_match(InstReg, Opcodes.OpLDZI) then
                    reg_read_ctrl.SelOutD <= "11";
                    dau_ctrl.OffsetSel <= DAU.OFF_ONE;
                    NextExecuteOpData.writeRegSelD <= "11";
                elsif std_match(InstReg, Opcodes.OpLDZD) then
                    reg_read_ctrl.SelOutD <= "11";
                    dau_ctrl.OffsetSel <= DAU.OFF_NEGONE;
                    NextExecuteOpData.writeRegSelD <= "11";
                end if;
            elsif std_match(InstReg, Opcodes.OpLDDY)
                    or std_match(InstReg, Opcodes.OpLDDZ)
                    or std_match(InstReg, Opcodes.OpPOP) then
                if CurState = 0 then
                    iau_ctrl.OffsetSel <= IAU.OFF_ZERO;
                    LoadInstReg <= '0';
                    
                elsif CurState = 1 then
                    startDataRd <= '0';
                    NextExecuteOpData.OpA <= DataDB;
                    NextExecuteOpData.writeRegEnS <= '1';
                    NextExecuteOpData.writeRegSelS <= decodeReg32d;
                end if;
                if std_match(InstReg, Opcodes.OpLDDY) then
                    reg_read_ctrl.SelOutD <= "10";
                    dau_ctrl.OffsetSel <= DAU.OFF_ARRAY;
                elsif std_match(InstReg, Opcodes.OpLDDZ) then
                    reg_read_ctrl.SelOutD <= "11";
                    dau_ctrl.OffsetSel <= DAU.OFF_ARRAY;
                elsif std_match(InstReg, Opcodes.OpPOP) then
                    dau_ctrl.SrcSel <= DAU.SRC_STACK;
                    if CurState = 0 then
                        dau_ctrl.OffsetSel <= DAU.OFF_ONE;
                    elsif CurState = 1 then
                        dau_ctrl.OffsetSel <= DAU.OFF_ZERO;
                    end if;
                end if;
            elsif std_match(InstReg, Opcodes.OpLDI) then
                -- Pass immediate through ALU into write unit
                NextExecuteOpData.writeRegEnS <= '1';
                NextExecuteOpData.writeRegSelS <= decodeReg16d;
                NextExecuteOpData.OpA <= decodeWordConstant;
            elsif std_match(InstReg, Opcodes.OpLDS) then
                -- Three cycle read.
                -- Cycle 0:
                --   - Increment ProgAB to get the memory address
                --   - Stop loading of instreg
                -- Cycle 1:
                --   - Do data read
                --   - Stop update of progAB
                -- Cycle 2:
                --   - Resume incrementing progAB
                dau_ctrl.SrcSel <= DAU.SRC_PDB;
                if CurState = 0 then
                    LoadInstReg <= '0';
                elsif CurState = 1 then
                    dau_ctrl.SrcSel <= DAU.SRC_PDB;
                    iau_ctrl.OffsetSel <= IAU.OFF_ZERO;
                    NextExecuteOpData.OpA <= DataDB;
                    NextExecuteOpData.writeRegEnS <= '1';
                    NextExecuteOpData.writeRegSelS <= decodeReg32d;
                    startDataRd <= '0';
                    LoadInstReg <= '0';
                end if;
            elsif (std_match(InstReg, Opcodes.OpST)
                    or std_match(InstReg, Opcodes.OpSTY)
                    or std_match(InstReg, Opcodes.OpSTZ))
                    and not(std_match(InstReg, Opcodes.OpSTS)
                    or std_match(InstReg, Opcodes.OpPUSH)) then
                -- Two cycle store instructions
                reg_read_ctrl.SelOutA <= decodeReg32d;
                DataDB <= reg_DataOutA;
                if CurState = 0 then
                    -- First cycle for store instruction.
                    -- On first cycle, do the following:
                    -- Put the address on the Data bus (already connected to double width output)
                    -- Put the data on the Data bus
                    -- Stop the InstReg from incrementing
                    LoadInstReg <= '0';
                    iau_ctrl.OffsetSel <= IAU.OFF_ZERO;
                elsif CurState = 1 then
                    NextExecuteOpData.writeRegEnD <= '1';
                    startDataWr <= '0';
                end if;
                -- The indexing D width register is written back with
                -- appropriate increment/decrement etc
                if std_match(InstReg, Opcodes.OpSTX) then
                    dau_ctrl.OffsetSel <= DAU.OFF_ZERO;
                    reg_read_ctrl.SelOutD <= "01";
                    NextExecuteOpData.writeRegSelD <= "01";
                elsif std_match(InstReg, Opcodes.OpSTXI) then
                    dau_ctrl.OffsetSel <= DAU.OFF_ONE;
                    reg_read_ctrl.SelOutD <= "01";
                    NextExecuteOpData.writeRegSelD <= "01";
                elsif std_match(InstReg, Opcodes.OpSTXD) then
                    dau_ctrl.OffsetSel <= DAU.OFF_NEGONE;
                    reg_read_ctrl.SelOutD <= "01";
                    NextExecuteOpData.writeRegSelD <= "01";
                elsif std_match(InstReg, Opcodes.OpSTY) then
                    dau_ctrl.OffsetSel <= DAU.OFF_ZERO;
                    reg_read_ctrl.SelOutD <= "10";
                    NextExecuteOpData.writeRegSelD <= "10";
                elsif std_match(InstReg, Opcodes.OpSTYI) then
                    dau_ctrl.OffsetSel <= DAU.OFF_ONE;
                    reg_read_ctrl.SelOutD <= "10";
                    NextExecuteOpData.writeRegSelD <= "10";
                elsif std_match(InstReg, Opcodes.OpSTYD) then
                    dau_ctrl.OffsetSel <= DAU.OFF_NEGONE;
                    reg_read_ctrl.SelOutD <= "10";
                    NextExecuteOpData.writeRegSelD <= "10";
                elsif std_match(InstReg, Opcodes.OpSTZ) then
                    dau_ctrl.OffsetSel <= DAU.OFF_ZERO;
                    reg_read_ctrl.SelOutD <= "11";
                    NextExecuteOpData.writeRegSelD <= "11";
                elsif std_match(InstReg, Opcodes.OpSTZI) then
                    dau_ctrl.OffsetSel <= DAU.OFF_ONE;
                    reg_read_ctrl.SelOutD <= "11";
                    NextExecuteOpData.writeRegSelD <= "11";
                elsif std_match(InstReg, Opcodes.OpSTZD) then
                    dau_ctrl.OffsetSel <= DAU.OFF_NEGONE;
                    reg_read_ctrl.SelOutD <= "11";
                    NextExecuteOpData.writeRegSelD <= "11";
                end if;
            elsif std_match(InstReg, Opcodes.OpSTDY)
                    or std_match(InstReg, Opcodes.OpSTDZ)
                    or std_match(InstReg, Opcodes.OpPUSH)
            then
                reg_read_ctrl.SelOutA <= decodeReg32d;
                DataDB <= reg_DataOutA;
                if CurState = 0 then
                    iau_ctrl.OffsetSel <= IAU.OFF_ZERO;
                    LoadInstReg <= '0';
                elsif CurState = 1 then
                    startDataWr <= '0';
                end if;
                if std_match(InstReg, Opcodes.OpSTDY) then
                    reg_read_ctrl.SelOutD <= "10";
                    dau_ctrl.OffsetSel <= DAU.OFF_ARRAY;
                elsif std_match(InstReg, Opcodes.OpSTDZ) then
                    reg_read_ctrl.SelOutD <= "11";
                    dau_ctrl.OffsetSel <= DAU.OFF_ARRAY;
                elsif std_match(InstReg, Opcodes.OpPUSH) then
                    dau_ctrl.SrcSel <= DAU.SRC_STACK;
                    if CurState = 0 then
                        dau_ctrl.OffsetSel <= DAU.OFF_ZERO;
                    elsif CurState = 1 then
                        dau_ctrl.OffsetSel <= DAU.OFF_NEGONE;
                    end if;
                end if;
            elsif std_match(InstReg, Opcodes.OpSTS) then
                reg_read_ctrl.SelOutA <= decodeReg32d;
                DataDB <= reg_DataOutA;
                dau_ctrl.SrcSel <= DAU.SRC_PDB;
                if CurState = 0 then
                    iau_ctrl.OffsetSel <= IAU.OFF_ONE;
                    LoadInstReg <= '0';
                elsif CurState = 1 then
                    iau_ctrl.OffsetSel <= IAU.OFF_ZERO;
                    startDataWr <= '0';
                    LoadInstReg <= '0';
                else
                    -- CurState = 2
                end if;
            --synthesis translate_off
            else
                assert (reset = '0' or now = 0 ns) report "Unknown instruction ";
            --synthesis translate_on
            end if;
        end if;
    end process DecodeProc;

    -----------------
    -----------------
    -- Execute Unit
    -----------------
    -----------------

    DataHazardComputeProc: process(NextExecuteOpData,
                                   reg_read_ctrl,
                                   DecodeUsedSreg)
        variable reg_slv: std_logic_vector(4 downto 0);
    begin
        -- This cpu is an in-order pipelined cpu.
        -- Therefore, we only need to worry about write-after-read
        -- data hazards. Read-after-write and write-after-write
        -- only occur in out-of-order cpus.

        -- Sources of write-after-read hazards:
        --  Registers (Write stage)
        --  Status register (Execute stage)
        --  
        --  Both registers and status registers are used in
        --  decode stage, with no resource use passed on
        --  to this logic right now. Need to change that.
        --  CurExecuteOpData, or another record in parallel,
        --  should include registers read from and status register
        --  read from in decode stage. For registers, can just use
        --  the reg_read_ctrl record. For status register, need to
        --  add something to facilitate this.
        --
        -- Then, we construct a DataLocks record by one-hot encoding
        -- all of the resources. For simplicity, we treat read and
        -- write as identical for locking, and keep lock throughout
        -- pipeline. This does create false dependencies, but it is
        -- simple and probably good enough for low pipeline depth here.
        decodeDataReadLocks <= (others => '0');
        decodeDataWriteLocks <= (others => '0');
        for i in 0 to 31 loop
            -- Assign register i lock flag
            reg_slv := std_logic_vector(to_unsigned(i, 5));
            if std_match(reg_slv, reg_read_ctrl.SelOutA) then
                decodeDataReadLocks(i) <= '1';
            elsif std_match(reg_slv, reg_read_ctrl.SelOutB) then
                decodeDataReadLocks(i) <= '1';
            elsif std_match(reg_slv, "11" & reg_read_ctrl.SelOutD & "-") then
                decodeDataReadLocks(i) <= '1';
            end if;
            if NextExecuteOpData.writeRegEnS = '1' and std_match(reg_slv, NextExecuteOpData.writeRegSelS) then
                decodeDataWriteLocks(i) <= '1';
            elsif NextExecuteOpData.writeRegEnD = '1' and std_match(reg_slv, "11" & NextExecuteOpData.writeRegSelD & "-") then
                decodeDataWriteLocks(i) <= '1';
            end if;
        end loop;

        if DecodeUsedSreg = '1' then
            decodeDataReadLocks(39 downto 32) <= (others => '1');
        else
            decodeDataWriteLocks(39 downto 32) <= NextExecuteOpData.ALUFlagMask;
        end if;
    end process DataHazardComputeProc;

    decodeExecuteHazards <= decodeDataReadLocks and executeDataLocks;
    decodeWriteHazards <= decodeDataReadLocks(31 downto 0) and writeDataLocks;

    DataHazardCheckProc: process(decodeExecuteHazards, decodeWriteHazards)
    begin
        if decodeExecuteHazards /= (decodeExecuteHazards'range => '0') then
            DecodeDataHazardPresent <= '1';
        elsif decodeWriteHazards /= (decodeWriteHazards'range => '0') then
            DecodeDataHazardPresent <= '1';
        else
            DecodeDataHazardPresent <= '0';
        end if;
    end process;

    Decode2ExecuteReg: process(clock)
    begin
        if rising_edge(clock) then
            if DecodeDataHazardPresent = '1' or reset = '0' then
                -- Bubble the pipeline, so no resource locks
                executeDataLocks <= (others => '0');
                --CurExecuteOpData <= ExecuteOpBubble;
                -- Put a bubble in the pipeline
                CurExecuteOpData.OpA <= (others => '0');
                CurExecuteOpData.OpB <= (others => '0');
                CurExecuteOpData.ALUOpCode <= ALUOp.ADD_Op;
                CurExecuteOpData.ALUFlagMask <= FlagMaskNone;
                CurExecuteOpData.writeRegEnS <= '0';
                CurExecuteOpData.writeRegSelS <= (others => '0');
                CurExecuteOpData.dataD <= dau_update;
                CurExecuteOpData.writeRegEnD <= '0';
                CurExecuteOpData.writeRegSelD <= (others => '0');
            else
                executeDataLocks <= decodeDataWriteLocks;
                CurExecuteOpData <= NextExecuteOpData;
            end if;
        end if;
    end process Decode2ExecuteReg;

    -- Connects with ALU and does ALU ops
    ExecuteProc: process(alu_Result,
                         reset,
                         CurExecuteOpData)
    begin
        NextWriteOpData.dataS <= alu_Result;
        NextWriteOpData.writeRegEnS <= '0';
        NextWriteOpData.writeRegSelS <= (others => '0');

        NextWriteOpData.dataD <= CurExecuteOpData.dataD; -- TODO proper pipelineing
        NextWriteOpData.writeRegEnD <= '0';
        NextWriteOpData.writeRegSelD <= (others => '0');
        if reset = '0' then
        else
            NextWriteOpData.writeRegEnS <= CurExecuteOpData.writeRegEnS;
            NextWriteOpData.writeRegSelS <= CurExecuteOpData.writeRegSelS;
            NextWriteOpData.writeRegEnD <= CurExecuteOpData.writeRegEnD;
            NextWriteOpData.writeRegSelD <= CurExecuteOpData.writeRegSelD;
        end if;
    end process ExecuteProc;


    -----------------
    -----------------
    -- Write Unit
    -----------------
    -----------------

    Execute2WriteReg: process(clock)
    begin
        if rising_edge(clock) then
            writeDataLocks <= executeDataLocks(31 downto 0);
            CurWriteOpData <= NextWriteOpData;
        end if;
    end process Execute2WriteReg;


    -- Connects with Register write interface and writes data
    WriteProc: process(CurWriteOpData)
    begin
        reg_write_ctrl.EnableInS <= CurWriteOpData.writeRegEnS;
        reg_write_ctrl.SelInS <= CurWriteOpData.writeRegSelS;
        reg_DataInS <= CurWriteOpData.dataS;

        reg_write_ctrl.EnableInD <= CurWriteOpData.writeRegEnD;
        reg_write_ctrl.SelInD <= CurWriteOpData.writeRegSelD;
        reg_DataInD <= CurWriteOpData.dataD;

    end process WriteProc;

end architecture;
