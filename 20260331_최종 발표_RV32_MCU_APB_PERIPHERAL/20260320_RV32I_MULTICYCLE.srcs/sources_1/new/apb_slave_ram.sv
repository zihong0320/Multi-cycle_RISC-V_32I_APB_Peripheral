module apb_slave_ram (
    input                        PCLK,
    //cpu
    input                 [ 2:0] funct3,
    //APB_bus
    input                 [31:0] PADDR,
    input                 [31:0] PWDATA,
    input                        PWRITE,
    input                        PENABLE,
          apb_if.slave_io        slv_RAM
);

    assign slv_RAM.PREADY = (PENABLE && slv_RAM.PSEL);

    data_mem U_RAM (
        .clk     (PCLK),
        //control_unit
        .i_funct3(3'h2),
        .dwe     (PREADY && PWRITE),
        //write
        .daddr   (PADDR),
        .dwdata  (PWDATA),
        //read
        .drdata  (slv_RAM.PRDATA)
    );

endmodule