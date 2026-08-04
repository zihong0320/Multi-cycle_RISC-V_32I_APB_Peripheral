`timescale 1ns / 1ps

module APB_GPIO (
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
    // External ports
    inout  logic [15:0] GPIO
);
    localparam [11:0] GPIO_CTL_ADDR = 12'h000;
    localparam [11:0] GPIO_ODATA_ADDR = 12'h004;
    localparam [11:0] GPIO_IDATA_ADDR = 12'h008;
    logic [15:0] GPIO_ODATA_REG, GPIO_CTL_REG, GPIO_IDATA_REG;  //GPIO_IDATA_NEXT;

    assign PREADY = (PENABLE & PSEL) ? 1'b1 : 1'b0;

    assign PRDATA = (PADDR[11:0] == GPIO_CTL_ADDR)   ? {16'h0000, GPIO_CTL_REG} :
                    (PADDR[11:0] == GPIO_ODATA_ADDR) ? {16'h0000, GPIO_ODATA_REG}:
                    (PADDR[11:0] == GPIO_IDATA_ADDR) ? {16'h0000, GPIO_IDATA_REG}: 32'hxxxxxxxx;

    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            GPIO_CTL_REG   <= 16'h0000;
            GPIO_ODATA_REG <= 16'h0000;
            //GPIO_IDATA_REG <= 16'h0000;
        end else begin
            if (PREADY) begin
                if (PWRITE) begin
                    case (PADDR[11:0])
                        GPIO_CTL_ADDR:   GPIO_CTL_REG   <= PWDATA[15:0];
                        GPIO_ODATA_ADDR: GPIO_ODATA_REG <= PWDATA[15:0];
                    endcase
                end
            end
            // else begin
            //     GPIO_IDATA_REG <= GPIO_IDATA_NEXT;
            // end
        end
    end

    gpio U_GPIO (
        .ctl   (GPIO_CTL_REG),
        .o_data(GPIO_ODATA_REG),
        .i_data(GPIO_IDATA_REG),
        .gpio  (GPIO)
    );

endmodule

module gpio (
    input        [15:0] ctl,
    input        [15:0] o_data,
    output logic [15:0] i_data,
    inout  logic [15:0] gpio
);
    genvar i;
    generate
        for (i = 0; i < 16; i++) begin
            assign gpio[i] = ctl[i] ? o_data[i] : 1'bz;
            assign i_data  = ~ctl[i] ? gpio[i] : 1'bz;
        end
    endgenerate
endmodule
