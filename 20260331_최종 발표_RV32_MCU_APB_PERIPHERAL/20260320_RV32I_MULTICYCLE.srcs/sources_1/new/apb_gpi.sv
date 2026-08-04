`timescale 1ns / 1ps

module APB_GPI (
    // BUS Global Signal
    input               PCLK,
    input               PRESET,
    // APB Interface Signal
    input        [31:0] PADDR,
    input        [31:0] PWDATA,
    input               PENABLE,
    input               PWRITE,
    input               PSEL,
    input        [15:0] GPI,
    output logic [31:0] PRDATA,
    output logic        PREADY
);
    localparam [11:0] GPI_CTL_ADDR = 12'h000;
    localparam [11:0] GPI_IDATA_ADDR = 12'h004;

    logic [15:0] GPI_CTL_REG;
    logic [15:0] GPI_IDATA_REG;

    //slave -> master
    assign PREADY = (PSEL & PENABLE) ? 1'b1 : 1'b0;

    assign PRDATA = (PADDR[11:0] == GPI_CTL_ADDR)   ? {16'h0000, GPI_CTL_REG} :
                    (PADDR[11:0] == GPI_IDATA_ADDR) ? {16'h0000, GPI_IDATA_REG}:32'hxxxxxxxx;


    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            GPI_CTL_REG   <= 16'h0000;
            //GPI_IDATA_REG <= 16'h0000;
        end else begin
            if (PREADY & PWRITE) begin
                case (PADDR[11:0])
                    GPI_CTL_ADDR: GPI_CTL_REG <= PWDATA[15:0];
                endcase
            end
        end
    end

    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin
            assign GPI_IDATA_REG[i] = (GPI_CTL_REG[i]) ? GPI[i] : 1'bz;
        end
    endgenerate

endmodule
