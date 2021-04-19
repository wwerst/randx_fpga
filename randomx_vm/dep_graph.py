from graphviz import Digraph
import random

from instruction import get_decoder_dict, Program


class DependencyNodes(object):

    def __init__(self):
        self.dig = Digraph()
        dig = self.dig
        self.r_nodes = {i: f"r{i}_0" for i in range(8)}
        self.a_nodes = {i: f"a{i}_0" for i in range(4)}
        self.f_nodes = {i: f"f{i}_0" for i in range(4)}
        self.e_nodes = {i: f"e{i}_0" for i in range(4)}
        for node_list in [self.r_nodes, self.a_nodes, self.f_nodes, self.e_nodes]:
            for i, node_name in node_list.items():
                dig.node(node_name, f"0_{node_name}_init")


class DependencyAnalyzer(object):

    def __init__(self, program):
        self.program = program

    def analyze(self):
        nodes = DependencyNodes()
        for num, inst in enumerate(self.program.insts):
            inst.add_dependencies(nodes, num)
        nodes.dig.render(view=True)


def main():
    decoder = get_decoder_dict()
    inst_bytes = []
    for i in range(256):
        rand_bytes = random.randint(0, 2**64).to_bytes(length=8, byteorder='little')
        inst_bytes.append(rand_bytes)

    program = Program(inst_bytes)
    print(program)
    analyzer = DependencyAnalyzer(program)
    analyzer.analyze()


if __name__ == '__main__':
    main()
