`timescale 1ns / 1ps

module tb_rv32i_bus ();

    logic        clk;
    logic        rst;
    logic [31:0] addr;
    logic [31:0] wdata;
    logic        wreq;
    logic        rreq;
    logic [31:0] paddr;
    logic [31:0] pwdata;
    logic        penable;
    logic        pwrite;
    logic [31:0] rdata;
    logic        ready;

    logic [31:0] prdata0;
    logic        pready0;

    logic [31:0] prdata5;
    logic        pready5;

    logic        psel0;
    logic        psel5;

    APB_master U_APB_MASTER (
        .pclk(clk),
        .presetn(rst),
        .addr(addr),
        .wdata(wdata),
        .wreq(wreq),
        .rreq(rreq),
        .paddr(paddr),
        .pwdata(pwdata),
        .penable(penable),
        .pwrite(pwrite),
        .rdata(rdata),
        .ready(ready),
        .prdata0(prdata0),
        .pready0(pready0),
        .psel0(psel0),
        .pready5(pready5),
        .prdata5(prdata5)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst = 0;
        @(negedge clk);
        @(negedge clk);
        rst = 1;

        @(posedge clk);
        #1;
        wreq  = 1'b1;
        addr  = 32'h1000_0000;
        wdata = 32'h0000_0041;

        @(psel0 && penable);
        pready0 = 1'b1;
        @(posedge clk);
        #1;
        pready0 = 1'b0;
        wreq = 1'b0;

        @(posedge clk);
        #1;
        rreq = 1'b1;
        addr = 32'h2000_4000;

        @(psel5 && penable);
        @(posedge clk);
        @(posedge clk);
        #1;
        pready5 = 1'b1;
        prdata5 = 32'h0000_0041;
        @(posedge clk);
        #1;
        pready0 = 1'b0;
        rreq = 1'b0;

        @(posedge clk);
        @(posedge clk);
        $stop;
    end

endmodule
