`timescale 1ns / 1ps

module tb_rv32i ();
    logic clk, rst;
    logic [7:0] GPI, GPO;
    wire [15:0] GPIO;

    rv32i_mcu dut (
        .*,
        .GPIO(GPIO)
    );

    always #5 clk = ~clk;

    initial begin
        clk  = 0;
        rst  = 1;
        GPI  = 8'h00;
        //GPO  = 16'h0000;
        //GPIO = 16'h0000;
        @(negedge clk);
        @(negedge clk);
        rst = 0;
        GPI = 8'haa;
        repeat (2000) @(negedge clk);
        $stop;
    end
endmodule
