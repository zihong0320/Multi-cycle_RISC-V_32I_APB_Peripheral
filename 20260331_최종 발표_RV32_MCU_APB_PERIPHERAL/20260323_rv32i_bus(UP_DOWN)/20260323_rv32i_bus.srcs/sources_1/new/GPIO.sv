`timescale 1ns / 1ps

module APB_GPIO (
    input  logic        pclk,
    input  logic        presetn,
    input  logic [31:0] paddr,
    input  logic [31:0] pwdata,
    input  logic        penable,
    input  logic        pwrite,
    input  logic        psel,
    output logic [31:0] prdata,
    output logic        pready,

    inout logic [15:0] gpio
);


    localparam [11:0] GPIO_CTL_ADDR = 12'h000;
    localparam [11:0] GPIO_ODATA_ADDR = 12'h004;
    localparam [11:0] GPIO_IDATA_ADDR = 12'h008;

    logic [15:0] gpio_ctl_reg;
    logic [15:0] gpio_odata_reg;
    logic [15:0] gpio_idata_reg;

    assign pready = (penable & psel) ? 1'b1 : 1'b0;

    always_comb begin
        prdata = 32'h0000_0000;
        if (psel && !pwrite && penable) begin
            case (paddr[11:0])
                GPIO_CTL_ADDR:   prdata = {16'h0000, gpio_ctl_reg};
                GPIO_ODATA_ADDR: prdata = {16'h0000, gpio_odata_reg};
                GPIO_IDATA_ADDR: prdata = {16'h0000, gpio_idata_reg};
            endcase
        end
    end

    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            gpio_ctl_reg   <= 16'h0000;
            gpio_odata_reg <= 16'h0000;
            // gpio_idata_reg <= 16'h0000;
        end else begin
            if (psel && penable && pwrite) begin
                case (paddr[11:0])
                    GPIO_CTL_ADDR:   gpio_ctl_reg <= pwdata[15:0];
                    GPIO_ODATA_ADDR: gpio_odata_reg <= pwdata[15:0];
                    // GPIO_IDATA_ADDR: gpio_idata_reg <= pwdata[15:0];
                endcase
            end
        end
    end

    gpio U_GPIO (
        .ctl(gpio_ctl_reg),
        .o_data(gpio_odata_reg),
        .i_data(gpio_idata_reg),
        .gpio(gpio)
    );

endmodule

module gpio (
    input  logic [15:0] ctl,
    input  logic [15:0] o_data,
    output logic [15:0] i_data,
    inout  logic [15:0] gpio
);

    genvar i;
    generate
        for (i = 0; i < 16; i++) begin
            assign gpio[i]   = ctl[i] ? o_data[i] : 1'bz;
            assign i_data[i] = gpio[i];
        end
    endgenerate
endmodule
