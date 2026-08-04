`timescale 1ns / 1ps

module BRAM (
    input logic clk,

    input  logic [31:0] paddr,
    input  logic [31:0] pwdata,
    input  logic        penable,
    input  logic        pwrite,
    input  logic        psel,
    output logic        pready,
    output logic [31:0] prdata
);

    logic [31:0] bmem[0:1024];  // 1024 * 4byte : 4k

    assign pready = (penable && psel) ? 1'b1 : 1'b0;

    always_ff @(posedge clk) begin
        if (psel & penable & pwrite) begin
            bmem[paddr[11:2]] <= pwdata;
        end
    end

    assign prdata = bmem[paddr[11:2]];

endmodule
