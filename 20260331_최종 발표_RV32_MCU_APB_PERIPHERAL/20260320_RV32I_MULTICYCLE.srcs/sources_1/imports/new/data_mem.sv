`timescale 1ns / 1ps
`include "define.vh"

module data_mem (
    input               clk,
    input               dwe,
    input        [ 2:0] i_funct3,
    input        [31:0] daddr,
    input        [31:0] dwdata,
    output logic [31:0] drdata
);
    logic [7:0] selected_byte;
    logic [15:0] selected_half;
    // byte address
    // logic [7:0] dmem[0:31];

    // assign drdata = {dmem[daddr], dmem[daddr+1], dmem[daddr+3], dmem[daddr+4]};

    // always_ff @(posedge clk) begin
    //     if (dwe) begin
    //         dmem[daddr+0] <= ddata[7:0];
    //         dmem[daddr+1] <= ddata[15:8];
    //         dmem[daddr+2] <= ddata[23:16];
    //         dmem[daddr+3] <= ddata[31:24];
    //     end
    // end


    // word address
    logic [31:0] dmem[0:255];
    always_ff @(posedge clk) begin
        if (dwe) begin
            case (i_funct3)
                `SB: begin
                    case (daddr[1:0])
                        2'b00: dmem[daddr[31:2]][7:0]   <= dwdata[7:0];
                        2'b01: dmem[daddr[31:2]][15:8]  <= dwdata[7:0];
                        2'b10: dmem[daddr[31:2]][23:16] <= dwdata[7:0];
                        2'b11: dmem[daddr[31:2]][31:24] <= dwdata[7:0];
                    endcase
                end
                `SH: begin
                    if (daddr[1]) dmem[daddr[31:2]][31:16] <= dwdata[15:0];
                    else dmem[daddr[31:2]][15:0] <= dwdata[15:0];
                end
                `SW: dmem[daddr[31:2]] <= dwdata;  // SW 
            endcase
        end
    end

    always_comb begin
        drdata = 0;
        selected_byte = 0;
        selected_half = 0;
        case (daddr[1:0])
            2'b00: selected_byte = dmem[daddr[31:2]][7:0];
            2'b01: selected_byte = dmem[daddr[31:2]][15:8];
            2'b10: selected_byte = dmem[daddr[31:2]][23:16];
            2'b11: selected_byte = dmem[daddr[31:2]][31:24];
        endcase

        if (daddr[1] == 1'b0) 
            selected_half = dmem[daddr[31:2]][15:0];
        else 
            selected_half = dmem[daddr[31:2]][31:16];

        case (i_funct3)
            `LB:  drdata = {{24{selected_byte[7]}}, selected_byte};
            `LH:  drdata = {{16{selected_half[15]}}, selected_half};
            `LW:  drdata = dmem[daddr[31:2]];  // LW
            `LBU: drdata = {{24{1'b0}}, selected_byte};
            `LHU: drdata = {{16{1'b0}}, selected_half};
        endcase
    end
endmodule
