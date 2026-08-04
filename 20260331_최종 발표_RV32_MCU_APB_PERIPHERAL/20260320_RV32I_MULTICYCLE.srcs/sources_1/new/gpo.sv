`timescale 1ns / 1ps

module APB_GPO (
    // BUS Global signal
    input               PCLK,
    input               PRESET,
    // APB Interface Signal
    input        [31:0] PADDR,
    input        [31:0] PWDATA,
    input               PENABLE,
    input               PWRITE,
    input               PSEL,
    output logic [31:0] PRDATA,
    output logic        PREADY,
    output logic [15:0] GPO_OUT
);
    localparam [11:0] GPO_CTL_ADDR = 12'h000;
    localparam [11:0] GPO_ODATA_ADDR = 12'h004;
    logic [15:0] GPO_ODATA_REG, GPO_CTL_REG;

    assign PREADY = (PENABLE & PSEL) ? 1'b1 : 1'b0;

    assign PRDATA = (PADDR[11:0] == GPO_CTL_ADDR)   ? {16'h0000, GPO_CTL_REG} :
                    (PADDR[11:0] == GPO_ODATA_ADDR) ? {16'h0000, GPO_ODATA_REG}:32'hxxxxxxxx;

    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            GPO_ODATA_REG <= 16'h0000;
            GPO_CTL_REG   <= 16'h0000;
        end else begin
            if (PREADY & PWRITE) begin
                case (PADDR[11:0])
                    GPO_CTL_ADDR:   GPO_CTL_REG <= PWDATA[15:0];
                    GPO_ODATA_ADDR: GPO_ODATA_REG <= PWDATA[15:0];
                endcase
            end
        end
    end

    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin
            assign GPO_OUT[i] = (GPO_CTL_REG[i]) ? GPO_ODATA_REG[i] : 1'bz;
        end
    endgenerate

endmodule
