/* Test Script
 */

#include <iostream>
#include <fstream>
#include <string>

int main(int argc, char **argv) {
    std::ifstream infile("../../program_data.hex");
    std::string line;
    int program[256];
    while (std::getline(infile, line))
    {
        program[0] = 100;
        std::cout << line << std::endl;
    }
    return 0;
}
