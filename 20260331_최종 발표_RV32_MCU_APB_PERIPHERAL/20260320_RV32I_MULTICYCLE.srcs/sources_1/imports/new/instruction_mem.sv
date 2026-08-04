`timescale 1ns / 1ps

module instruction_mem (
    input  [31:0] instr_addr,
    output [31:0] instr_data
);

    logic [31:0] rom[0:255];

    initial begin
        //$readmemh("riscv_rv32i_rom_data.mem", rom);
        //$readmemh("slave_ram.mem", rom);
        //$readmemh("APB_GPO.mem", rom);
        //$readmemh("APB_BRAM_GPO_GPI.mem", rom);
        $readmemh("APB_GPIO_LED_BLINK.mem", rom);
        //rom[0]  = 32'h004182b3;  // ADD X5, X3, X4
        
        // I-type
        // rom[0]  = 32'hfff18293;  // ADDI  X5, X3, -1
        // rom[1]  = 32'hfff1a293;  // SLTI  X5, X3, ffffffff
        // rom[2]  = 32'hfff1b293;  // SLTIU X5, X3, ffffffff
        // rom[3]  = 32'hfff1c293;  // XORI  X5, X3, ffffffff
        // rom[4]  = 32'hfff1f293;  // ANDI  X5, X3, ffffffff
        // rom[5]  = 32'hfff1e293;  // ORI   X5, X3, ffffffff
        // rom[6]  = 32'h00129313;  // SLLI  X6, X5, 1
        // rom[7]  = 32'h0012d313;  // SRLI  X6, X5, 1
        // rom[8]  = 32'h4012d313;  // SRAI  X6, X5, 1

        // S-type
        // rom[0]  = 32'h00812123;  // SW X8, 2(X2), SW x8, x2, 2
        // rom[1]  = 32'h00831123;  // SH X8, 2(X6), SH x8, x6, 2
        // rom[2]  = 32'h00861123;  // SH x8, 2(x12)
        // rom[3]  = 32'h00870123;  // SB X8, 2(X14), SB x8, x14, 2
        // rom[4]  = 32'h00898123;  // SB x8, 2(x19)  
        // rom[5]  = 32'h008c0123;  // SB x8, 2(x24)  
        // rom[6]  = 32'h008e8123;  // SB x8, 2(x29)

        // IL-type
        // for LBU, LHU test
        // rom[0] = 32'h405182b3;  // SUB x5, x3, x5   -> x5 = fffffffe
        // rom[1] = 32'h00112337;  // LUI x6, 0x00112  
        // rom[2] = 32'h23330313;  // ADDI x6, x6, 0x233 -> x6 = 00112233

        // rom[3] = 32'h00502223;  // SW x5, 4(x0)    -> addr 4(dmem[1]) = fffffffe
        // rom[4] = 32'h00602423;  // SW x6, 8(x0)    -> addr 8(dmem[2]) = 00112233

        // rom[5] = 32'h00400383;  // LB x7, 4(x0)    -> x7 = fffffffe (addr 4)
        // rom[6] = 32'h00401403;  // LH x8, 4(x0)    -> x8 = fffffffe (addr 4)

        // rom[7] = 32'h00800483;  // LB x9, 8(x0)    -> x9 = 00000033 (addr 8)
        // rom[8] = 32'h00900503;  // LB x10, 9(x0)   -> x10 = 00000022 (addr 9)
        // rom[9] = 32'h00a00583;  // LB x11, 10(x0)  -> x11 = 00000011 (addr 10)
        // rom[10]= 32'h00b00603;  // LB x12, 11(x0)  -> x12 = 00000000 (addr 11)

        // rom[11] = 32'h00404683; // LBU x13, 4(x0)  -> x13 = 000000fe (addr 4)
        // rom[12] = 32'h00405703; // LHU x14, 4(x0)  -> x14 = 0000fffe (addr 4)
        
        
        // UL, UA-type
        //rom[1]  = 32'h001000b7;  // LUI X1, 32(00100(16) => 32'h00100000) - because of zero padding
        //rom[1]  = 32'h00100097;  // AUIPC X1, 32(00100(16) => 32'h00100000)
        
        // J-type
        //rom[1]  = 32'h020001ef; // JAL X3, 32(4 + 20(16) = 24(16))
        //rom[9]  = 32'h005302b3; // (24번지): ADD X5, X6, X5      

        // JL-type
        // rom[1]  = 32'h040401e7; // JALR X3, X8, 64(8(10) + 40(16) == 48(16))
        // rom[18] = 32'h004182b3; // ADD X5, X3, X4 (8(=x[3])+ 4(16) == c(16))
        // rom[19] = 32'h005302b3; // (76번지): ADD X5, X6, X5

        // B-type
        // rom[1]   = 32'h00728663; // BEQ  X5, X7, 12   -> true
        // rom[4]   = 32'h00718663; // BEQ  X3, X7, 12   -> false
        // rom[5]   = 32'h00729663; // BNE  X5, X7, 12   -> false
        // rom[6]   = 32'h00719663; // BNE  X3, X7, 12   -> true
        // rom[9]   = 32'h0071c663; // BLT  X3, X7, 12   -> true
        // rom[12]  = 32'h0072c663; // BLT  X5, X7, 12   -> flase
        // rom[13]  = 32'h0072d663; // BGE  X5, X7, 12   -> true
        // rom[16]  = 32'h0071d663; // BGE  X3, X7, 12   -> flase

        // rom[17]  = 32'h404182b3; // SUB  X5, X3, X4   -> ffffffff = -1
        // rom[18]  = 32'h0072e663; // BLTU X5, X7, 12   -> false
        // rom[19]  = 32'h0072c663; // BLT  X5, X7, 12   -> true
        // rom[22]  = 32'h0053f663; // BGEU X7, X5, 12   -> false
        // rom[23]  = 32'h0053d663; // BGE  X7, X5, 12   -> true



        // 임의로 test
        // rom[0]  = 32'h004182b3;  // ADD X5, X3, X4
        // rom[1]  = 32'h00512123;  // SW X5, 2(X2), SW x5, x2, 2
        // rom[2]  = 32'h00212383;  // LW X7, 2(X2), LW X7, X2, 2
        // rom[3]  = 32'h00438413;  // ADDi X8, X7, 4
        // rom[4]  = 32'h00840463;  // BEQ X8, X8, 4
        // rom[5]  = 32'h004182b3;  // ADD X5, X3, X4
        // rom[6]  = 32'h00812123;  // SW X2, 2(X8), SW x2, x8, 2
        // //rom[7]  = 32'h001000b7;  // LUI X1, 32(00100(16) => 32'h00100000) - because of zero padding
        // rom[7]  = 32'h00010097;  // AUIPC X1, 16(00010(16) => 32'h00010000)
        // //rom[8]  = 32'h000101ef; // JAL X3, 16(1C + 20(16) = 24(36))
        // rom[8]  = 32'h040381e7; // JALR X3, X7, 64(8(10) + 40(16) == 48(16))
        // rom[18] = 32'h004182b3;  // ADD X5, X3, X4 (24(16)+ 4(16) == 28(16))
        // rom[19] = 32'h005302b3; // (76번지): ADD X5, X6, X5

        // R-type
        // rom[0]  = 32'h004182b3;  //ADD X5, X3, X4  -> 00000007
        // rom[1]  = 32'h404182b3;  //SUB X5, X3, X4  -> ffffffff = -1
        // rom[2]  = 32'h40428133;  //SUB X2, X5, X4  -> fffffffb = -5
        // rom[3]  = 32'h403203b3;  //SUB X7, X4, X3  -> 00000001
        // rom[4]  = 32'h00181333;  //SLL X6, X16, X1 -> 00000020 = 32
        // rom[5]  = 32'h0072a333;  //SLT X6, X5, X7  -> 00000001
        // rom[6]  = 32'h0072b333;  //SLTU X6, X5, X7 -> 00000000
        // rom[7]  = 32'h0072c433;  //XOR X8, X5, X7  -> fffffffe = -2
        // rom[8]  = 32'h0072d433;  //SRL X8, X5, X7  -> 7fffffff
        // rom[9]  = 32'h4072d433;  //SRA X8, X5, X7  -> ffffffff
        // rom[10] = 32'h0012e4b3;  //OR X9, X5, X1  -> ffffffff
        // rom[11] = 32'h0012f4b3;  //AND X9, X5, X1 -> 00000001

    end

    assign instr_data = rom[instr_addr[31:2]];

endmodule
