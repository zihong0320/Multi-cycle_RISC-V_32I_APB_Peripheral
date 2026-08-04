`timescale 1ns / 1ps

module BRAM (
    //Soc internal sig
    input PCLK,
    // input       PRESET,

    //APB Interface signal
    input               PENABLE,
    input               PWRITE,
    input        [31:0] PADDR,
    input        [31:0] PWDATA,
    input               PSEL,     //RAM
    output logic [31:0] PRDATA,   //RAM
    output logic        PREADY    //RAM
);
    logic [31:0] bmem[0:1024];

    assign PREADY = (PENABLE & PSEL) ? 1'b1 : 1'b0;

    always_ff @(posedge PCLK) begin
        if (PSEL & PENABLE & PWRITE) begin
            bmem[PADDR[11:2]] <= PWDATA;  // SW
        end
    end

    assign PRDATA = bmem[PADDR[11:2]];


endmodule
