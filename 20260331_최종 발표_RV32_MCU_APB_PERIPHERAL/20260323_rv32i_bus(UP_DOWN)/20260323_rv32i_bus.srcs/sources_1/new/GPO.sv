`timescale 1ns / 1ps

module GPO (
    input logic        pclk,
    input logic        presetn,
    input logic [31:0] paddr,
    input logic [31:0] pwdata,
    input logic        pwrite,
    input logic        psel,
    input logic        penable,

    output logic [31:0] prdata,
    output logic        pready,

    output logic [15:0] o_gpo
);

    localparam [11:0] GPO_CTL_ADDR = 12'h000;
    localparam [11:0] GPO_ODATA_ADDR = 12'h004;

    logic [15:0] gpo_ctl_reg;
    logic [15:0] gpo_odata_reg;

    assign pready = (penable & psel) ? 1'b1 : 1'b0;

    always_comb begin
        prdata = 32'h0000_0000;

        if (psel && !pwrite && penable) begin
            case (paddr[11:0])
                GPO_CTL_ADDR:   prdata = {16'h0000, gpo_ctl_reg};
                GPO_ODATA_ADDR: prdata = {16'h0000, gpo_odata_reg};
            endcase
        end
    end

    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            gpo_ctl_reg   <= 16'h0000;
            gpo_odata_reg <= 16'h0000;
        end else begin
            if (psel && penable && pwrite) begin
                case (paddr[11:0])
                    GPO_CTL_ADDR:   gpo_ctl_reg <= pwdata[15:0];
                    GPO_ODATA_ADDR: gpo_odata_reg <= pwdata[15:0];
                endcase
            end
        end
    end

    genvar i;
    generate
        for (i = 0; i < 16; i++) begin : gen_gpo_out
            assign o_gpo[i] = (gpo_ctl_reg[i]) ? gpo_odata_reg[i] : 1'b0;
        end
    endgenerate

endmodule
