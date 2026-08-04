`timescale 1ns / 1ps
`include "define.vh"

module rv32i_datapath (
    input         clk,
    input         rst_n,
    input         pc_en,
    input         rf_we,
    input         branch,
    input         alu_src,
    input         jal,
    input         jalr,
    input  [ 3:0] alu_control,
    input  [31:0] instr_data,
    input  [31:0] bus_rdata,
    input  [ 2:0] rfwd_src,
    output [31:0] instr_addr,
    output [31:0] bus_addr,
    output [31:0] bus_wdata
);
    logic [31:0] alu_result, alurs2_data, rfwb_data, imm_data;
    logic [31:0] pc_ua_out;
    logic [31:0] pc_jal_out;
    logic btaken;
    // decoder
    logic [31:0]
        i_dec_rs1, o_dec_rs1, i_dec_rs2, o_dec_rs2, i_dec_imm, o_dec_imm;
    // execute
    logic [31:0] o_exe_rs2, o_exe_alu_result;
    //  mem
    logic [31:0] o_mem_drdata;
    // write back to register file
    logic [31:0] o_wb_imm;
    assign bus_addr  = o_exe_alu_result;
    assign bus_wdata = o_exe_rs2;

    // fetch, execute
    program_counter U_PC (
        .clk(clk),
        .rst_n(rst_n),
        .btaken(btaken),
        .branch(branch),  // from alu comparator
        .jal(jal),
        .jalr(jalr),
        .pc_en(pc_en),
        .rd1_data(o_dec_rs1),
        .imm_data(o_dec_imm),
        .pc_out(instr_addr),  // from control unit for B-type
        .pc_ua_out(pc_ua_out),
        .pc_jal_out(pc_jal_out)
    );

    // decode
    register_file U_REG_FILE (
        .clk  (clk),
        .rst_n  (rst_n),
        .raddr1  (instr_data[19:15]),
        .raddr2  (instr_data[24:20]),
        .waddr   (instr_data[11:7]),
        .wdata(rfwb_data),
        .rf_we(rf_we),
        .rdata1  (i_dec_rs1),
        .rdata2  (i_dec_rs2)
    );
    imm_extender U_IMM_EXTEND (
        .instr_data(instr_data),
        .imm_data  (imm_data)
    );

    register U_DEC_REG_RS1 (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(i_dec_rs1),
        .data_out(o_dec_rs1)
    );

    register U_DEC_REG_RS2 (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(i_dec_rs2),
        .data_out(o_dec_rs2)
    );

    register U_DEC_IMM_EXT (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(imm_data),
        .data_out(o_dec_imm)
    );

    // execute
    mux_2x1 U_MUX_ALUSRC_RS2 (
        .in0    (o_dec_rs2),
        .in1    (o_dec_imm),
        .mux_sel(alu_src),
        .out_mux(alurs2_data)
    );
    alu U_ALU (
        .rd1        (o_dec_rs1),
        .rd2        (alurs2_data),
        .alu_control(alu_control),
        .alu_result (alu_result),
        .btaken     (btaken)
    );


    register U_EXE_ALU_RESULT (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(alu_result),
        .data_out(o_exe_alu_result)  // to daddr  
    );

    register U_EXE_REG_RS2 (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(o_dec_rs2),  // from alu result
        .data_out(o_exe_rs2)  // to data mem_wdata
    );

    // mem to WB 
    register U_MEM_REG_DRDATA (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(bus_rdata),  // from alu result
        .data_out(o_mem_drdata)  // to data mem_wdata
    );

    // write back to Register file
    // register U_DEC_IMM_DRDATA (
    //     .clk(clk),
    //     .rst_n(rst_n),
    //     .data_in(o_dec_imm),  // from alu result
    //     .data_out(o_wb_imm)  // to data mem_wdata
    // );

    // to register file
    mux_8x1 U_WB_MUX (
        .in0(alu_result),    // from ALU result, because process with execute state
        .in1(o_mem_drdata),  // from data memory
        .in2(o_dec_imm),  // from imm extend, for LUI
        .in3(pc_ua_out),  // from pc + imm extend, for AUIPC
        .in4(pc_jal_out),  // from PC + 4, for JAL/JALR
        .mux_sel(rfwd_src),
        .out_mux(rfwb_data)
    );
endmodule

module mux_2x1 (
    input        [31:0] in0,      // sel 0
    input        [31:0] in1,      // sel 1
    input               mux_sel,
    output logic [31:0] out_mux
);
    assign out_mux = (mux_sel) ? in1 : in0;

endmodule

module mux_8x1 (
    input [31:0] in0,
    input [31:0] in1,
    input [31:0] in2,
    input [31:0] in3,
    input [31:0] in4,
    input [2:0] mux_sel,
    output logic [31:0] out_mux
);

    always_comb begin
        case (mux_sel)
            3'b000: out_mux = in0;
            3'b001: out_mux = in1;
            3'b010: out_mux = in2;
            3'b011: out_mux = in3;
            3'b100: out_mux = in4;
            default: out_mux = 32'b0;
        endcase 
    end
endmodule

module imm_extender (
    input        [31:0] instr_data,
    output logic [31:0] imm_data
);
    always_comb begin
        imm_data = 32'd0;
        case (instr_data[6:0])  // opcode
            `S_TYPE: begin
                imm_data = {
                    {20{instr_data[31]}}, instr_data[31:25], instr_data[11:7]
                };
            end
            `I_TYPE, `IL_TYPE: begin  // load
                imm_data = {{20{instr_data[31]}}, instr_data[31:20]};
            end
            `B_TYPE: begin
                imm_data = {
                    {20{instr_data[31]}},
                    instr_data[7],  // imm bit 11
                    instr_data[30:25],
                    instr_data[11:8],
                    1'b0
                };
            end
            `UL_TYPE, `UA_TYPE: begin
                imm_data = {instr_data[31:12], 12'b0};
            end
            `JR_TYPE: begin
                imm_data = {{20{instr_data[31]}}, instr_data[31:20]};
            end
            `J_TYPE: begin
                imm_data = {
                    {12{instr_data[31]}},
                    instr_data[19:12],
                    instr_data[20],
                    instr_data[30:21],
                    1'b0
                };
            end
        endcase
    end
endmodule

module register_file (
    input         clk,
    input         rst_n,
    input  [ 4:0] raddr1,  // instruction code RS1
    input  [ 4:0] raddr2,  // instruction code RS1
    input  [ 4:0] waddr,   // instruction code RD
    input  [31:0] wdata,   // instruction RD write data
    input         rf_we,   // Register File Write Enable
    output [31:0] rdata1,  // Register File RS1 output
    output [31:0] rdata2   // Register File RS2 output
);
    logic [31:0] register_file[1:31];  //x0 must have zero

    // `ifdef SIMULATION
    //     initial begin
    //         for (int i = 0; i < 32; i++) begin
    //             register_file[i] = i;
    //         end
    //     end
    // `endif

    //output CL
    assign rdata1 = (raddr1 != 0) ? register_file[raddr1] : 32'h0;
    assign rdata2 = (raddr2 != 0) ? register_file[raddr2] : 32'h0;

    always_ff @(posedge clk) begin
        if (rst_n & rf_we) begin
            register_file[waddr] <= wdata;
        end
    end
endmodule

module alu (
    input        [31:0] rd1,          // RS1
    input        [31:0] rd2,          // RS2
    input        [ 3:0] alu_control,  // funct7[5], funct3 : 4bit
    output logic [31:0] alu_result,
    output logic        btaken
);

    always_comb begin
        alu_result = 0;
        case (alu_control)
            `ADD: alu_result = rd1 + rd2;  // add rd = rs1 + rs2
            `SUB: alu_result = rd1 - rd2;  // sub rd = rs1 - rs2
            `SLL: alu_result = rd1 << rd2[4:0];  //sll rd = rs1 << rs2
            `SLT:
            alu_result = ($signed(rd1) < $signed(rd2));  //slt rd = rs1 < rs2 
            `SLTU: alu_result = (rd1 < rd2);  //sltu rd = rs1 < rs2
            `XOR: alu_result = rd1 ^ rd2;  // xor rd = rs1 ^ rs2
            `SRL: alu_result = rd1 >> rd2[4:0];  // srl rd = rs1 >> rs2
            `SRA:
            alu_result = $signed(rd1) >>>
                rd2[4:0];  // sra rd = rs1 >>> rs2, msb extenstion
            `OR: alu_result = rd1 | rd2;  // or rd = rs1 | rs2
            `AND: alu_result = rd1 & rd2;  // and rd = rs1 & rs2
        endcase
    end

    always_comb begin
        btaken = 0;
        case (alu_control)
            `BEQ: begin
                if (rd1 == rd2) btaken = 1;
            end
            `BNE: begin
                if (rd1 != rd2) btaken = 1;
            end
            `BLT: begin
                if ($signed(rd1) < $signed(rd2)) btaken = 1;
            end
            `BGE: begin
                if ($signed(rd1) >= $signed(rd2)) btaken = 1;
            end
            `BLTU: begin
                if (rd1 < rd2) btaken = 1;
            end
            `BGEU: begin
                if (rd1 >= rd2) btaken = 1;
            end
        endcase
    end

endmodule

module program_counter (
    input               clk,
    input               rst_n,
    input               btaken,     // from alu for B-type
    input               branch,     // from control unit for B-type
    input               jal,
    input               jalr,
    input               pc_en,
    input        [31:0] rd1_data,
    input        [31:0] imm_data,
    output logic [31:0] pc_out,
    output logic [31:0] pc_ua_out,
    output logic [31:0] pc_jal_out
);
    logic [31:0] pc_next, o_exe_pcnext, pc_imm_out, o_jal_oc, pc_4_out;
    logic [31:0] pc_rd1i_out;  // pc_rd1_imm_out
    logic [31:0] pc_jrr_out;  // pc_jalr_rs1_out
    logic [31:0] pc_next_in1;
    logic        pc_next_sel;

    assign pc_next_in1 = jalr ? {pc_imm_out[31:1], 1'b0} : pc_imm_out;
    assign pc_next_sel = (btaken & branch) | jal | jalr;

    // execute
    mux_2x1 U_JALR_MUX (
        .in0(pc_out),
        .in1(rd1_data),
        .mux_sel(jalr),
        .out_mux(pc_jrr_out)
    );

    pc_alu U_PC_IMM (
        .a(imm_data),
        .b(pc_jrr_out),
        .pc_alu_out(pc_imm_out)
    );
    pc_alu U_PC_4 (
        .a(32'd4),
        .b(pc_out),
        .pc_alu_out(pc_4_out)
    );
    mux_2x1 PC_NEXT_MUX (
        .in0    (pc_4_out),
        .in1    (pc_next_in1),
        .mux_sel(pc_next_sel),
        .out_mux(pc_next)
    );

    register U_PCNEXT_REG (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(pc_next),
        .data_out(o_exe_pcnext)
    );
    // execute
    register U_UA_REG (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(pc_imm_out),
        .data_out(pc_ua_out)
    );
    register U_JAL_REG (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(pc_4_out),
        .data_out(pc_jal_out)
    );
    // fetch
    register_en U_PC_REG (
        .clk(clk),
        .rst_n(rst_n),
        .en(pc_en),
        .data_in(o_exe_pcnext),
        .data_out(pc_out)
    );
endmodule

module pc_alu (
    input  [31:0] a,
    input  [31:0] b,
    output [31:0] pc_alu_out
);
    assign pc_alu_out = a + b;
endmodule

module register (
    input         clk,
    input         rst_n,
    input  [31:0] data_in,
    output [31:0] data_out
);
    logic [31:0] register;

    assign data_out = register;

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            register <= 0;
        end else begin
            register <= data_in;
        end
    end

endmodule


module register_en (
    input         clk,
    input         rst_n,
    input         en,
    input  [31:0] data_in,
    output [31:0] data_out
);
    logic [31:0] register;

    assign data_out = register;

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            register <= 0;
        end else begin
            if (en) register <= data_in;
        end
    end

endmodule

