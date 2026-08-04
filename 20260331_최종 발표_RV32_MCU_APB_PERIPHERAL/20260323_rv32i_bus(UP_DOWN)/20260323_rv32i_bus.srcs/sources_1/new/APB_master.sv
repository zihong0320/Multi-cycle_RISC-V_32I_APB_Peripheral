`timescale 1ns / 1ps

module APB_master (
    input  logic        pclk,
    input  logic        presetn,
    // cpu -> APB master (request)
    input  logic [31:0] addr,
    input  logic [31:0] wdata,
    input  logic        wreq,
    input  logic        rreq,
    // APB master -> APB bus (to slave)
    output logic [31:0] paddr,
    output logic [31:0] pwdata,
    output logic        penable,
    output logic        pwrite,
    output logic        psel0,    // ram
    output logic        psel1,    // gpo
    output logic        psel2,    // gpi
    output logic        psel3,    // gpio
    output logic        psel4,    // fnd
    output logic        psel5,    // uart
    // APB bus -> APB master (from slave)
    input  logic        pslverr,
    input  logic        pready0,  // from ram
    input  logic        pready1,  // from gpo
    input  logic        pready2,  // from gpi
    input  logic        pready3,  // from gpio
    input  logic        pready4,  // from fnd
    input  logic        pready5,  // from uart
    input  logic [31:0] prdata0,  // from ram
    input  logic [31:0] prdata1,  // from gpo
    input  logic [31:0] prdata2,  // from gpi
    input  logic [31:0] prdata3,  // from gpio
    input  logic [31:0] prdata4,  // from fnd
    input  logic [31:0] prdata5,  // from uart
    // APB master -> cpu (response)
    output logic        slverr,
    output logic [31:0] rdata,
    output logic        ready
);

    logic [31:0] paddr_next, pwdata_next;
    logic decode_en, pwrite_next;
    // logic mux_ready;

    apb_mux U_APB_MUX (
        .pready0(pready0),
        .pready1(pready1),
        .pready2(pready2),
        .pready3(pready3),
        .pready4(pready4),
        .pready5(pready5),
        .sel(paddr),
        .ready(ready), // mux_ready
        .rdata(rdata),
        .prdata0(prdata0),
        .prdata1(prdata1),
        .prdata2(prdata2),
        .prdata3(prdata3),
        .prdata4(prdata4),
        .prdata5(prdata5)
    );

    addr_decoder U_ADDR_DECODER (
        .en(decode_en),
        .addr(paddr),
        .psel0(psel0),
        .psel1(psel1),
        .psel2(psel2),
        .psel3(psel3),
        .psel4(psel4),
        .psel5(psel5)
    );

    typedef enum logic [1:0] {
        IDLE,
        SETUP,
        ACCESS
    } state_t;
    state_t c_state, n_state;

    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            c_state <= IDLE;
            paddr   <= 32'b0;
            pwdata  <= 32'b0;
            pwrite  <= 1'b0;
        end else begin
            c_state <= n_state;
            paddr   <= paddr_next;
            pwdata  <= pwdata_next;
            pwrite  <= pwrite_next;
        end
    end

    // next
    always_comb begin
        decode_en = 1'b0;
        penable = 1'b0;
        paddr_next = paddr;
        pwdata_next = pwdata;
        pwrite_next = pwrite;
        n_state = c_state;
        case (c_state)
            IDLE: begin
                decode_en = 0;
                penable = 0;
                paddr_next = 32'd0;
                pwdata_next = 32'd0;
                pwrite_next = 1'b0;
                if (wreq | rreq) begin
                    paddr_next  = addr;
                    pwdata_next = wdata;
                    if (wreq) begin
                        pwrite_next = 1'b1;
                    end else begin
                        pwrite_next = 1'b0;
                    end
                    n_state = SETUP;
                end
            end
            SETUP: begin
                decode_en = 1;
                penable   = 0;
                n_state   = ACCESS;
            end
            ACCESS: begin
                decode_en = 1;
                penable   = 1;
                if (ready) begin
                    n_state = IDLE;
                end
            end
        endcase
    end

   //  assign ready = (c_state == ACCESS && mux_ready);

endmodule

module addr_decoder (
    input               en,
    input  logic [31:0] addr,
    output logic        psel0,
    output logic        psel1,
    output logic        psel2,
    output logic        psel3,
    output logic        psel4,
    output logic        psel5
);

    always_comb begin
        psel0 = 1'b0;  // idle : 0
        psel1 = 1'b0;  // idle : 0
        psel2 = 1'b0;  // idle : 0
        psel3 = 1'b0;  // idle : 0
        psel4 = 1'b0;  // idle : 0
        psel5 = 1'b0;  // idle : 0
        if (en) begin
            case (addr[31:28])  // instead of casex
                4'h1: psel0 = 1'b1;
                4'h2: begin
                    case (addr[15:12])
                        4'h0: psel1 = 1'b1;
                        4'h1: psel2 = 1'b1;
                        4'h2: psel3 = 1'b1;
                        4'h3: psel4 = 1'b1;
                        4'h4: psel5 = 1'b1;
                    endcase
                end
            endcase
        end
    end
endmodule

module apb_mux (
    input  logic        pready0,
    input  logic        pready1,
    input  logic        pready2,
    input  logic        pready3,
    input  logic        pready4,
    input  logic        pready5,
    input  logic [31:0] sel,
    input  logic [31:0] prdata0,
    input  logic [31:0] prdata1,
    input  logic [31:0] prdata2,
    input  logic [31:0] prdata3,
    input  logic [31:0] prdata4,
    input  logic [31:0] prdata5,
    output logic        ready,
    output logic [31:0] rdata
);

    always_comb begin
        rdata = 32'h0000_0000;
        ready = 1'b0;

        case (sel[31:28])  // instead of casex
            4'h1: begin
                rdata = prdata0;
                ready = pready0;
            end
            4'h2: begin
                case (sel[15:12])
                    4'h0: begin
                        rdata = prdata1;
                        ready = pready1;
                    end
                    4'h1: begin
                        rdata = prdata2;
                        ready = pready2;
                    end
                    4'h2: begin
                        rdata = prdata3;
                        ready = pready3;
                    end
                    4'h3: begin
                        rdata = prdata4;
                        ready = pready4;
                    end
                    4'h4: begin
                        rdata = prdata5;
                        ready = pready5;
                    end
                endcase
            end
            default: begin
                rdata = 32'h0000_0000;
                ready = 1'b0;
            end
        endcase
    end
endmodule
