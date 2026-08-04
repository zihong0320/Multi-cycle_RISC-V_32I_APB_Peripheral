`timescale 1ns / 1ps

module GPI (
    input  logic        pclk,
    input  logic        presetn,
    input  logic [31:0] paddr,
    input  logic [31:0] pwdata,
    input  logic        pwrite,
    input  logic        psel,
    input  logic        penable,

    output logic [31:0] prdata,
    output logic        pready,

    input  logic [15:0] i_gpi
);

    localparam [11:0] GPI_CTL_ADDR   = 12'h000;
    localparam [11:0] GPI_IDATA_ADDR = 12'h004;

    logic [15:0] gpi_ctl_reg;

    logic [15:0] sync1_reg;
    logic [15:0] sync2_reg;

    assign pready = 1'b1;

    always_comb begin
        prdata = 32'h0000_0000; 

        if (psel && !pwrite && penable) begin
            case (paddr[11:0])
                GPI_CTL_ADDR: prdata = {16'h0000, gpi_ctl_reg};
                
                GPI_IDATA_ADDR: begin
                    prdata = {16'h0000, (sync2_reg & gpi_ctl_reg)};
                end
            endcase
        end
    end

    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            gpi_ctl_reg <= 16'h0000;
            sync1_reg   <= 16'h0000;
            sync2_reg   <= 16'h0000;
        end else begin
            sync1_reg <= i_gpi;
            sync2_reg <= sync1_reg;

            if (psel && penable && pwrite) begin
                case (paddr[11:0])
                    GPI_CTL_ADDR: gpi_ctl_reg <= pwdata[15:0];
                endcase
            end
        end
    end

endmodule
