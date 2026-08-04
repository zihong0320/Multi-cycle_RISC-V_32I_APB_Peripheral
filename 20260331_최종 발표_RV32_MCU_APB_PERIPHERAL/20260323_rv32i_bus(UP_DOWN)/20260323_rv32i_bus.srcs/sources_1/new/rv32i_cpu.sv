`timescale 1ns / 1ps
`include "define.vh"

module rv32i_cpu (
    input         clk,
    input         rst_n,
    input  [31:0] instr_data,
    input  [31:0] bus_rdata,
    input         bus_ready,   // master
    output [31:0] instr_addr,
    output        bus_wreq,    // master, dwe
    output        bus_rreq,    // master
    output [ 2:0] o_funct3,
    output [31:0] bus_addr,
    output [31:0] bus_wdata
);

    logic pc_en, rf_we, alu_src;
    logic [2:0] rfwd_src;
    logic [3:0] alu_control;
    logic jal, jalr;

    control_unit U_CONTROL_UNIT (
        .clk(clk),
        .rst_n(rst_n),
        .funct7(instr_data[31:25]),
        .funct3(instr_data[14:12]),
        .opcode(instr_data[6:0]),
        .pc_en(pc_en),  // for multi cycle Fetch : pc
        .rf_we(rf_we),
        .branch(branch),
        .jal(jal),
        .jalr(jalr),
        .alu_src(alu_src),
        .alu_control(alu_control),
        .rfwd_src(rfwd_src),
        .o_funct3(o_funct3),
        .ready(bus_ready),  // master
        .wreq(bus_wreq),  // master .dwe(dwe)
        .rreq(bus_rreq)  // master
    );

    rv32i_datapath U_RV32I_DATAPATH (.*);

endmodule

module control_unit (
    input              clk,
    input              rst_n,
    input        [6:0] funct7,
    input        [2:0] funct3,
    input        [6:0] opcode,
    input              ready,        // master
    output logic       pc_en,
    output logic       rf_we,
    output logic       branch,
    output logic       alu_src,
    output logic [3:0] alu_control,
    output logic [2:0] rfwd_src,
    output logic [2:0] o_funct3,
    output logic       wreq,         // master, dwe
    output logic       rreq,         // master
    output logic       jal,
    output logic       jalr
);

    typedef enum {
        FETCH,
        DECODE,
        EXECUTE,
        MEM,
        WB
    } state_e;

    state_e c_state, n_state;

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            c_state <= FETCH;
        end else begin
            c_state <= n_state;
        end
    end

    always_comb begin
        n_state = c_state;
        case (c_state)
            FETCH: begin
                n_state = DECODE;
            end
            DECODE: begin
                n_state = EXECUTE;
            end
            EXECUTE: begin
                case (opcode)
                    `JR_TYPE, `J_TYPE, `UA_TYPE, `UL_TYPE, `B_TYPE, `I_TYPE, `R_TYPE :begin
                        n_state = FETCH;
                    end
                    `S_TYPE: begin
                        n_state = MEM;
                    end
                    `IL_TYPE: begin
                        n_state = MEM;
                    end
                endcase
            end
            MEM: begin
                case (opcode)
                    `S_TYPE: begin
                        if (ready) begin
                            n_state = FETCH;
                        end
                    end
                    `IL_TYPE: begin
                        if (ready) begin //ready plus ham if problem cut!
                            n_state = WB;
                        end
                    end
                endcase
            end
            WB: begin
               //  if (ready) begin
                    n_state = FETCH;
               // end
            end
        endcase
    end

    always_comb begin
        pc_en       = 1'b0;
        rf_we       = 1'b0;
        branch      = 1'b0;
        jal         = 1'b0;
        jalr        = 1'b0;
        alu_src     = 1'b0;
        alu_control = 4'b0000;
        rfwd_src    = 2'b00;
        o_funct3    = 3'b000;  // for S type, IL type
        wreq        = 1'b0;
        rreq        = 1'b0;
        case (c_state)
            FETCH: begin
                pc_en = 1'b1;
            end
            DECODE: begin
            end
            EXECUTE: begin
                case (opcode)
                    `R_TYPE: begin
                        rf_we       = 1'b1;  // next state FETCH
                        alu_src     = 1'b0;
                        alu_control = {funct7[5], funct3};
                    end
                    `B_TYPE: begin
                        branch      = 1'b1;
                        alu_src     = 1'b0;
                        alu_control = {1'b0, funct3};
                    end
                    `S_TYPE: begin
                        alu_src     = 1'b1;
                        alu_control = 4'b0000;
                    end
                    `IL_TYPE: begin
                        alu_src     = 1'b1;
                        alu_control = 4'b0000;
                    end
                    `I_TYPE: begin
                        rf_we   = 1'b1;  // next state FETCH
                        alu_src = 1'b1;
                        if (funct3 == 3'b101) alu_control = {funct7[5], funct3};
                        else alu_control = {1'b0, funct3};
                    end
                    `UL_TYPE: begin
                        rf_we = 1'b1;  // next state FETCH
                        rfwd_src = 3'b010;
                    end
                    `UA_TYPE: begin
                        rf_we = 1'b1;  // next state FETCH
                        rfwd_src = 3'b011;
                    end
                    `J_TYPE: begin
                        rf_we = 1'b1;  // next state FETCH
                        jal = 1'b1;
                        rfwd_src = 3'b100;
                    end
                    `JR_TYPE: begin
                        rf_we = 1'b1;  // next state FETCH
                        jalr = 1'b1;
                        rfwd_src = 3'b100;
                    end
                endcase
            end
            MEM: begin
                if (opcode == `S_TYPE) wreq = 1'b1;
                if (opcode == `IL_TYPE) rreq = 1'b1;
                o_funct3 = funct3;
            end
            WB: begin
                // IL_TYPE
                rf_we    = 1'b1; // next state FETCH
                rfwd_src = 3'b001;
            end
        endcase
    end

`ifdef SIMULATION
    logic [63:0] opcode_type;
    logic [63:0] alu_ctrl_mode;

    always_comb begin
        case (opcode)
            `R_TYPE:  opcode_type = "R_TYPE";
            `I_TYPE:  opcode_type = "I_TYPE";
            `S_TYPE:  opcode_type = "S_TYPE";
            `B_TYPE:  opcode_type = "B_TYPE";
            `IL_TYPE: opcode_type = "IL_TYPE";
            `J_TYPE:  opcode_type = "J_TYPE";
            `JR_TYPE: opcode_type = "JR_TYPE";
            `UL_TYPE: opcode_type = "UL_TYPE";
            `UA_TYPE: opcode_type = "UA_TYPE";
            default:  opcode_type = "UNKNOWN";
        endcase
    end

    always_comb begin
        alu_ctrl_mode = "NONE";

        case (opcode)
            `R_TYPE: begin
                case (alu_control)
                    `ADD  : alu_ctrl_mode = "ADD";
                    `SUB  : alu_ctrl_mode = "SUB";
                    `SLL  : alu_ctrl_mode = "SLL";
                    `SLT  : alu_ctrl_mode = "SLT";
                    `SLTU : alu_ctrl_mode = "SLTU";
                    `XOR  : alu_ctrl_mode = "XOR";
                    `SRL  : alu_ctrl_mode = "SRL";
                    `SRA  : alu_ctrl_mode = "SRA";
                    `OR   : alu_ctrl_mode = "OR";
                    `AND  : alu_ctrl_mode = "AND";
                    default:alu_ctrl_mode = "UNKNOWN";
                endcase
            end

            `I_TYPE: begin
                case (alu_control)
                    `ADD  : alu_ctrl_mode = "ADDI";
                    `SLL  : alu_ctrl_mode = "SLLI";
                    `SLT  : alu_ctrl_mode = "SLTI";
                    `SLTU : alu_ctrl_mode = "SLTIU";
                    `XOR  : alu_ctrl_mode = "XORI";
                    `SRL  : alu_ctrl_mode = "SRLI";
                    `SRA  : alu_ctrl_mode = "SRAI";
                    `OR   : alu_ctrl_mode = "ORI";
                    `AND  : alu_ctrl_mode = "ANDI";
                    default:alu_ctrl_mode = "UNKNOWN";
                endcase
            end

            `B_TYPE: begin
                case (alu_control)
                    `BEQ: alu_ctrl_mode = "BEQ";
                    `BNE: alu_ctrl_mode = "BNE";
                    `BLT: alu_ctrl_mode = "BLT";
                    `BGE: alu_ctrl_mode = "BGE";
                    `BLTU: alu_ctrl_mode = "BLTU";
                    `BGEU: alu_ctrl_mode = "BGEU";
                    default: alu_ctrl_mode = "UNKNOWN";
                endcase
            end

            `IL_TYPE: begin
                case (funct3)
                    `LB   : alu_ctrl_mode = "LB";
                    `LH   : alu_ctrl_mode = "LH";
                    `LW   : alu_ctrl_mode = "LW";
                    `LBU  : alu_ctrl_mode = "LBU";
                    `LHU  : alu_ctrl_mode = "LHU";
                    default:alu_ctrl_mode = "UNKNOWN";
                endcase
            end

            `S_TYPE: begin
                case (funct3)
                    `SB   : alu_ctrl_mode = "SB";
                    `SH   : alu_ctrl_mode = "SH";
                    `SW   : alu_ctrl_mode = "SW";
                    default:alu_ctrl_mode = "UNKNOWN";
                endcase
            end

            `J_TYPE:  alu_ctrl_mode = "JAL";
            `JR_TYPE: alu_ctrl_mode = "JALR";
            `UL_TYPE: alu_ctrl_mode = "LUI";
            `UA_TYPE: alu_ctrl_mode = "AUIPC";

            default: alu_ctrl_mode = "NONE";
        endcase
    end
`endif
endmodule

