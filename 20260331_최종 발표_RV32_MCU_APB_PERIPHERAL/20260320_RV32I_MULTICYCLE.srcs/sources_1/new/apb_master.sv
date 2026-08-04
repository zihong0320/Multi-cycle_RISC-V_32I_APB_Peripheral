`timescale 1ns / 1ps

module APB_Master (
    // BUS Global signal
    input PCLK,
    input PRESET,

    // SoC Internal signal with CPU
    input  [31:0] Addr,
    input  [31:0] Wdata,
    input         WREQ,   // from cpu, Write request signal dwe
    input         RREQ,   // from cpu, Read request signal dre
    //output        SlvERR,
    output [31:0] Rdata,
    output        Ready,

    // APB Interface signal
    output logic [31:0] PADDR,    // need register
    output logic [31:0] PWDATA,   // need register
    output logic        PENABLE,
    output logic        PWRITE,
    output logic        PSEL0,    // RAM
    output logic        PSEL1,    // GPO
    output logic        PSEL2,    // GPI
    output logic        PSEL3,    // GPIO
    output logic        PSEL4,    // FND
    output logic        PSEL5,    // UART
    input        [31:0] PRDATA0,  // from RAM
    input        [31:0] PRDATA1,  // from GPO
    input        [31:0] PRDATA2,  // from GPI
    input        [31:0] PRDATA3,  // from GPIO
    input        [31:0] PRDATA4,  // from FND
    input        [31:0] PRDATA5,  // from UART
    input               PREADY0,
    input               PREADY1,
    input               PREADY2,
    input               PREADY3,
    input               PREADY4,
    input               PREADY5
);
    //logic [31:0] w_Addr, w_Wdata;

    typedef enum {
        IDLE,
        SETUP,
        ACCESS
    } apb_state_e;

    apb_state_e c_state, n_state;

    logic [31:0] PADDR_next, PWDATA_next;
    logic decode_en, PWRITE_next;

    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            c_state <= IDLE;
            PADDR   <= 32'd0;
            PWDATA  <= 32'd0;
            PWRITE  <= 1'b0;
        end else begin
            c_state <= n_state;
            PADDR   <= PADDR_next;
            PWDATA  <= PWDATA_next;
            PWRITE  <= PWRITE_next;
        end
    end

    // next
    always_comb begin
        decode_en = 0;
        PENABLE = 0;
        PADDR_next = PADDR;
        PWDATA_next = PWDATA;
        PWRITE_next = PWRITE;
        n_state = c_state;
        case (c_state)
            IDLE: begin
                decode_en = 0;
                PENABLE = 0;
                PADDR_next = 0;
                PWDATA_next = 0;
                PWRITE_next = 0;
                if (WREQ | RREQ) begin
                    PADDR_next  = Addr;
                    PWDATA_next = Wdata;
                    if (WREQ) PWRITE_next = 1;
                    else PWRITE_next = 0;
                    n_state = SETUP;
                end
            end
            SETUP: begin
                decode_en = 1;
                PENABLE   = 0;
                n_state   = ACCESS;
            end
            ACCESS: begin
                decode_en = 1;
                PENABLE   = 1;
                if (Ready) begin
                    n_state = IDLE;
                end
            end
        endcase
    end

    // register U_Addr_REG (
    //     .clk     (PCLK),
    //     .rst     (PRESETn),
    //     .data_in (Addr),
    //     .data_out(w_Addr)
    // );

    // register U_Wdata_REG (
    //     .clk     (PCLK),
    //     .rst     (PRESETn),
    //     .data_in (Wdata),
    //     .data_out(w_Wdata)
    // );

    addr_decoder U_Addr_DECODE (
        .en(decode_en),
        .addr(PADDR),
        .psel0(PSEL0),  // RAM
        .psel1(PSEL1),  // GPO
        .psel2(PSEL2),  // GPI
        .psel3(PSEL3),  // GPIO
        .psel4(PSEL4),  // FND
        .psel5(PSEL5)  // UART
    );

    apb_mux U_APB_MUX (
        .sel    (PADDR),
        .PRDATA0(PRDATA0),
        .PRDATA1(PRDATA1),
        .PRDATA2(PRDATA2),
        .PRDATA3(PRDATA3),
        .PRDATA4(PRDATA4),
        .PRDATA5(PRDATA5),
        .PREADY0(PREADY0),
        .PREADY1(PREADY1),
        .PREADY2(PREADY2),
        .PREADY3(PREADY3),
        .PREADY4(PREADY4),
        .PREADY5(PREADY5),
        .Rdata  (Rdata),
        .Ready  (Ready)
    );

endmodule

module addr_decoder (
    input               en,
    input        [31:0] addr,
    output logic        psel0,  // RAM
    output logic        psel1,  // GPO
    output logic        psel2,  // GPI
    output logic        psel3,  // GPIO
    output logic        psel4,  // FND
    output logic        psel5   // UART
);
    always_comb begin
        psel0 = 0;  // idle : 0
        psel1 = 0;  // idle : 0
        psel2 = 0;  // idle : 0
        psel3 = 0;  // idle : 0
        psel4 = 0;  // idle : 0
        psel5 = 0;  // idle : 0
        if (en) begin
            case (addr[31:28])
                4'b0001: begin
                    psel0 = 1;  // RAM
                end
                4'b0010: begin
                    psel0 = 0;
                    psel1 = 0;
                    psel2 = 0;
                    psel3 = 0;
                    psel4 = 0;
                    psel5 = 0;
                    case (addr[15:12])
                        4'b0000: psel1 = 1;  // GPO
                        4'b0001: psel2 = 1;  // GPI
                        4'b0010: psel3 = 1;  // GPIO
                        4'b0011: psel4 = 1;  // FND
                        4'b0100: psel5 = 1;  // UART
                    endcase
                end
            endcase

        end
    end
endmodule

module apb_mux (
    input        [31:0] sel,
    input        [31:0] PRDATA0,  // sel 0
    input        [31:0] PRDATA1,  // sel 1
    input        [31:0] PRDATA2,  // sel 2
    input        [31:0] PRDATA3,  // sel 3
    input        [31:0] PRDATA4,  // sel 4
    input        [31:0] PRDATA5,  // sel 5
    input               PREADY0,
    input               PREADY1,
    input               PREADY2,
    input               PREADY3,
    input               PREADY4,
    input               PREADY5,
    output logic [31:0] Rdata,
    output logic        Ready
);
    always_comb begin
        Rdata = 32'h0000_0000;
        Ready = 1'b0;

        case (sel[31:28])
            4'b0001: begin
                Rdata = PRDATA0;  // RAM
                Ready = PREADY0;
            end
            4'b0010: begin
                case (sel[15:12])
                    4'b0000: begin
                        Rdata = PRDATA1;  // GPO
                        Ready = PREADY1;
                    end
                    4'b0001: begin
                        Rdata = PRDATA2;  // GPI
                        Ready = PREADY2;
                    end
                    4'b0010: begin
                        Rdata = PRDATA3;  // GPIO
                        Ready = PREADY3;
                    end
                    4'b0011: begin
                        Rdata = PRDATA4;  // FND
                        Ready = PREADY4;
                    end
                    4'b0100: begin
                        Rdata = PRDATA5;  // UART
                        Ready = PREADY5;
                    end
                endcase
            end
            default: begin
                Rdata = 32'hxxxx_xxxx;
                Ready = 1'bx;
            end
        endcase
    end

endmodule
