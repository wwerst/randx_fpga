import random
import struct
import unittest


def get_decoder_dict():
    """Builds a dictionary for lookup of opcode."""
    instruction_weights = [
        ("IADD_RS",  16),
        ("IADD_M",   7),
        ("ISUB_R",   16),
        ("ISUB_M",   7),
        ("IMUL_R",   16),
        ("IMUL_M",   4),
        ("IMULH_R",  4),
        ("IMULH_M",  1),
        ("ISMULH_R", 4),
        ("ISMULH_M", 1),
        ("IMUL_RCP", 8),
        ("INEG_R",   2),
        ("IXOR_R",   15),
        ("IXOR_M",   5),
        ("IROR_R",   8),
        ("IROL_R",   2),
        ("ISWAP_R",  4),
        ("FSWAP_R",  4),
        ("FADD_R",   16),
        ("FADD_M",   5),
        ("FSUB_R",   16),
        ("FSUB_M",   5),
        ("FSCAL_R",  6),
        ("FMUL_R",   32),
        ("FDIV_M",   4),
        ("FSQRT_R",  6),
        ("CBRANCH",  25),
        ("CFROUND",  1),
        ("ISTORE",   16),
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


class InstructionByteCode(object):
    DECODER_DICT = get_decoder_dict()

    def __init__(self, instr_bytes):
        (self.imm32,  # [63:32] I
         self.mod,    # [31:24] B
         self.src,    # [23:16] B
         self.dst,    # [15:8] B
         self.opcode) = struct.unpack("<IBBBB", instr_bytes)

    def get_instruction(self):
        instr_name = self.DECODER_DICT[self.opcode]
        name_to_cls = {
            "IADD_RS",
            "IADD_M",
            "ISUB_R",
            "ISUB_M",
            "IMUL_R",
            "IMUL_M",
            "IMULH_R",
            "IMULH_M",
            "ISMULH_R",
            "ISMULH_M",
            "IMUL_RCP",
            "INEG_R",
            "IXOR_R",
            "IXOR_M",
            "IROR_R",
            "IROL_R",
            "ISWAP_R",
            "FSWAP_R",
            "FADD_R",
            "FADD_M",
            "FSUB_R",
            "FSUB_M",
            "FSCAL_R",
            "FMUL_R",
            "FDIV_M",
            "FSQRT_R",
            "CBRANCH",
            "CFROUND",
            "ISTORE",
            "NOP",
        }
        return name_to_cls[instr_name]

    def __str__(self):
        return self.get_instruction()

    __repr__ = __str__


class BaseInstruction(object):

    def __init__(self):
        pass


if __name__ == '__main__':
    decoder = get_decoder_dict()
    for i in range(256):
        rand_bytes = random.randint(0, 2**64).to_bytes(length=8, byteorder='little')
        instr = InstructionByteCode(rand_bytes)
        print(instr)
