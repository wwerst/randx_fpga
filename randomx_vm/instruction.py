from abc import ABC, abstractmethod

import ctypes
import random
import struct
import unittest


def get_decoder_dict():
    """Builds a dictionary for lookup of opcode."""
    instruction_weights = [
        ("IADD_RS",  16),     #  |16/256|IADD_RS
        ("IADD_M",   7),      #  |7/256|IADD_M
        ("ISUB_R",   16),     #  |16/256|ISUB_R
        ("ISUB_M",   7),      #  |7/256|ISUB_M
        ("IMUL_R",   16),     #  |16/256|IMUL_R
        ("IMUL_M",   4),      #  |4/256|IMUL_M
        ("IMULH_R",  4),      #  |4/256|IMULH_R
        ("IMULH_M",  1),      #  |1/256|IMULH_M
        ("ISMULH_R", 4),      #  |4/256|ISMULH_R
        ("ISMULH_M", 1),      #  |1/256|ISMULH_M
        ("IMUL_RCP", 8),      #  |8/256|IMUL_RCP
        ("INEG_R",   2),      #  |2/256|INEG_R
        ("IXOR_R",   15),     #  |15/256|IXOR_R
        ("IXOR_M",   5),      #  |5/256|IXOR_M
        ("IROR_R",   8),      #  |8/256|IROR_R
        ("IROL_R",   2),      #  |2/256|IROL_R
        ("ISWAP_R",  4),      #  |4/256|ISWAP_R
        ("FSWAP_R",  4),      #  |4/256|FSWAP_R
        ("FADD_R",   16),     #  |16/256|FADD_R
        ("FADD_M",   5),      #  |5/256|FADD_M
        ("FSUB_R",   16),     #  |16/256|FSUB_R
        ("FSUB_M",   5),      #  |5/256|FSUB_M
        ("FSCAL_R",  6),      #  |6/256|FSCAL_R
        ("FMUL_R",   32),     #  |32/256|FMUL_R
        ("FDIV_M",   4),      #  |4/256|FDIV_M
        ("FSQRT_R",  6),      #  |6/256|FSQRT_R
        ("CBRANCH",  25),     #  |25/256|CBRANCH
        ("CFROUND",  1),      #  |1/256|CFROUND
        ("ISTORE",   16),     #  |16/256|ISTORE
        ("NOP",      0),      
        ]
    # Separate the codes and weights into separate lists
    code_names, weights = zip(*instruction_weights)
    assert sum(weights) == 256, 'Instruction weights should sum to 256'
    opcode_dict = dict()
    cumul_code = 0
    for code_name, weight in instruction_weights:
        for code in range(cumul_code, cumul_code + weight):
            opcode_dict[code] = code_name
        cumul_code = cumul_code + weight
    # Check results
    assert cumul_code == 256
    code_weights = {code_name: 0 for code_name in code_names}
    for i in range(256):
        code_name = opcode_dict[i]
        code_weights[code_name] += 1
    # Check that the code_weights match the original instruction_weights
    for orig_code_name, orig_code_weight in instruction_weights:
        assert code_weights[orig_code_name] == orig_code_weight
    return opcode_dict


class InstructionBuilder(object):
    def __init__(self):
        self._decoder_dict = get_decoder_dict()
        self._name_to_cls = {
            "IADD_RS": IADD_RS_Inst,
            "IADD_M": IADD_M_Inst,
            "ISUB_R": NOP_Inst,
            "ISUB_M": NOP_Inst,
            "IMUL_R": NOP_Inst,
            "IMUL_M": NOP_Inst,
            "IMULH_R": NOP_Inst,
            "IMULH_M": NOP_Inst,
            "ISMULH_R": NOP_Inst,
            "ISMULH_M": NOP_Inst,
            "IMUL_RCP": NOP_Inst,
            "INEG_R": NOP_Inst,
            "IXOR_R": NOP_Inst,
            "IXOR_M": NOP_Inst,
            "IROR_R": NOP_Inst,
            "IROL_R": NOP_Inst,
            "ISWAP_R": NOP_Inst,
            "FSWAP_R": NOP_Inst,
            "FADD_R": NOP_Inst,
            "FADD_M": NOP_Inst,
            "FSUB_R": NOP_Inst,
            "FSUB_M": NOP_Inst,
            "FSCAL_R": NOP_Inst,
            "FMUL_R": NOP_Inst,
            "FDIV_M": NOP_Inst,
            "FSQRT_R": NOP_Inst,
            "CBRANCH": NOP_Inst,
            "CFROUND": NOP_Inst,
            "ISTORE": NOP_Inst,
            "NOP": NOP_Inst,
        }

    def _inst_name_to_cls(self, inst_struct):
        instr_name = self._decoder_dict[inst_struct.opcode]
        return self._name_to_cls[instr_name]

    def build_instruction(self, inst_struct):
        inst_class = self._inst_name_to_cls(inst_struct)
        return inst_class(inst_struct)


class InstructionStruct(ctypes.Structure):
    _pack_ = 1
    _fields_ = [
        ("imm32", ctypes.c_uint32),
        ("mod", ctypes.c_uint8),
        ("src", ctypes.c_uint8),
        ("dst", ctypes.c_uint8),
        ("opcode", ctypes.c_uint8),
        ]


class Program(object):

    def __init__(self, inst_bytes):
        self.inst_structs = []
        for i in range(len(inst_bytes)):
            inst_bytearr = inst_bytes[i]
            self.inst_structs.append(
                InstructionStruct.from_buffer_copy(
                    inst_bytearr)
                )
        self.insts = []

        builder = InstructionBuilder()

        for inst_struct in self.inst_structs:
            inst = builder.build_instruction(inst_struct)
            self.insts.append(inst)

    def __str__(self):
        return "Program:\n" + "\n".join([f"{line_no+1:3d}:    {str(o)}" for line_no, o in enumerate(self.insts)])


class BaseInstByteCode(ABC):

    def __init__(self):
        self.idst = None
        self.fdst = None
        self.isrc = None
        self.fsrc = None
        self.fp_mode_src = None    # The R register that is the source for the fp_mode
        self.branch_target = None
        self.cache_level = None

    @abstractmethod
    def __str__(self):
        raise NotImplementedError()

    @abstractmethod
    def __repr__(self):
        raise NotImplementedError()


REGISTERS_COUNT = 8
REGISTERS_COUNT_FLT = 4


def get_read_sp_level(inst_struct, reg_count=None):
    src_reg = inst_struct.src % reg_count
    dst_reg = inst_struct.dst % reg_count

    if src_reg == dst_reg:
        return 3   # ScratchPad L3
    elif inst_struct.mod % 4 == 0:
        return 2   # ScratchPad L2
    return 1       # ScratchPad L1


def get_int_read_sp_level(inst_struct):
    return get_read_sp_level(inst_struct, reg_count=REGISTERS_COUNT)


def get_flt_read_sp_level(inst_struct):
    return get_read_sp_level(inst_struct, reg_count=REGISTERS_COUNT_FLT)


class IADD_RS_Inst(BaseInstByteCode):

    def __init__(self, inst_struct):
        super().__init__()
        self.idst = inst_struct.dst % REGISTERS_COUNT
        self.isrc = inst_struct.src % REGISTERS_COUNT

    def __str__(self):
        return f"IADD_RS R{self.idst}, R{self.isrc}"

    __repr__ = __str__


class IADD_M_Inst(BaseInstByteCode):

    def __init__(self, inst_struct):
        super().__init__()
        self.idst = inst_struct.dst % REGISTERS_COUNT
        self.isrc = inst_struct.src % REGISTERS_COUNT
        self.cache_level = get_int_read_sp_level(inst_struct)

    def __str__(self):
        return f"IADD_M R{self.idst}, L{self.cache_level}[mem]"

    __repr__ = __str__


class NOP_Inst(BaseInstByteCode):

    def __init__(self, inst_struct):
        super().__init__()

    def __str__(self):
        return "NOP"

    __repr__ = __str__


if __name__ == '__main__':
    decoder = get_decoder_dict()
    inst_bytes = []
    for i in range(256):
        rand_bytes = random.randint(0, 2**64).to_bytes(length=8, byteorder='little')
        inst_bytes.append(rand_bytes)

    program = Program(inst_bytes)
    print(program)

