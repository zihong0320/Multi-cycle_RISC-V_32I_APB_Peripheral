`timescale 1ns / 1ps

module rv32i_mcu (
    input  logic        clk,
    input  logic        rst_n,
    // input  logic [ 7:0] gpi,
    output logic [15:0] gpo,
    inout  logic [15:0] gpio,
    output logic [ 3:0] fnd_digit,
    output logic [ 7:0] fnd_data,
    input  logic        rx,
    output logic        tx
);
    wire sys_rst_n = ~rst_n;
    logic dwe;
    logic [2:0] o_funct3;
    logic [31:0] instr_addr, instr_data, bus_addr, bus_wdata, bus_rdata;
    logic bus_wreq, bus_rreq, bus_ready;
    logic [31:0] paddr, pwdata;
    logic pwrite, penable;
    logic [31:0] prdata0, prdata1, prdata2, prdata3, prdata4, prdata5;
    logic psel0, psel1, psel2, psel3, psel4, psel5;
    logic pready0, pready1, pready2, pready3, pready4, pready5;

    instruction_mem U_INSTRUCTION_MEM (.*);

    rv32i_cpu U_RV32I (
        .*,
        .rst_n(sys_rst_n),
        .o_funct3(o_funct3)
    );

    APB_master U_APB_MASTER (
        .pclk(clk),
        .presetn(sys_rst_n),
        .addr(bus_addr),
        .wdata(bus_wdata),
        .wreq(bus_wreq),
        .rreq(bus_rreq),
        .paddr(paddr),
        .pwdata(pwdata),
        .penable(penable),
        .pwrite(pwrite),
        .psel0(psel0),  // ram
        .psel1(psel1),  // gpo
        .psel2(psel2),  // gpi
        .psel3(psel3),  // gpio
        .psel4(psel4),  // fnd
        .psel5(psel5),  // uart
        .pslverr(pslverr),
        .pready0(pready0),  // from ram
        .pready1(pready1),  // from gpo
        .pready2(pready2),  // from gpi
        .pready3(pready3),  // from gpio
        .pready4(pready4),  // from fnd
        .pready5(pready5),  // from uart
        .prdata0(prdata0),  // from ram
        .prdata1(prdata1),  // from gpo
        .prdata2(prdata2),  // from gpi
        .prdata3(prdata3),  // from gpio
        .prdata4(prdata4),  // from fnd
        .prdata5(prdata5),  // from uart
        .slverr(slverr),
        .rdata(bus_rdata),
        .ready(bus_ready)
    );

    BRAM U_BRAM (
        .*,
        .psel  (psel0),
        .prdata(prdata0),
        .pready(pready0)
    );
    
    GPO U_GPO (
        .pclk(clk),
        .presetn(sys_rst_n),
        .paddr(paddr),
        .pwdata(pwdata),
        .pwrite(pwrite),
        .psel(psel1),
        .penable(penable),
        .prdata(prdata1),
        .pready(pready1),
        .o_gpo(gpo)
    );
    
    /*
    GPI U_GPI (
        .pclk(clk),
        .presetn(rst_n),
        .paddr(paddr),
        .pwdata(pwdata),
        .pwrite(pwrite),
        .psel(psel2),
        .penable(penable),
        .prdata(prdata2),
        .pready(pready2),
        .i_gpi(gpi)
    );
    */
    APB_GPIO U_GPIO (
        .pclk(clk),
        .presetn(sys_rst_n),
        .paddr(paddr),
        .pwdata(pwdata),
        .penable(penable),
        .pwrite(pwrite),
        .psel(psel3),
        .prdata(prdata3),
        .pready(pready3),
        .gpio(gpio)
    );

    FND U_FND (
        .pclk(clk),
        .presetn(sys_rst_n),
        .paddr(paddr),
        .pwdata(pwdata),
        .pwrite(pwrite),
        .psel(psel4),
        .penable(penable),
        .prdata(prdata4),
        .pready(pready4),
        .o_fnd_digit(fnd_digit),
        .o_fnd_data(fnd_data)
    );

    UART U_UART (
        .pclk(clk),
        .presetn(sys_rst_n),
        .paddr(paddr),
        .pwdata(pwdata),
        .pwrite(pwrite),
        .psel(psel5),
        .penable(penable),
        .prdata(prdata5),
        .pready(pready5),
        .i_uart_rx(rx),
        .o_uart_tx(tx)
    );

endmodule
