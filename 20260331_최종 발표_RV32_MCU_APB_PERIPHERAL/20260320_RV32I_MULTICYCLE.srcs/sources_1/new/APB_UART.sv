`timescale 1ns / 1ps

module APB_UART (
    // BUS Global signal
    input               PCLK,
    input               PRESET,
    // APB Interface Signal
    input        [31:0] PADDR,
    input        [31:0] PWDATA,
    input               PENABLE,
    input               PWRITE,
    input               PSEL,
    input               uart_rx,
    output              uart_tx,
    output logic [31:0] PRDATA,
    output logic        PREADY
);

    localparam [11:0] UART_CTL_ADDR = 12'h000;
    localparam [11:0] UART_BAUD_ADDR = 12'h004;
    localparam [11:0] UART_STATUS_ADDR = 12'h008;
    localparam [11:0] UART_TX_DATA_ADDR = 12'h00c;
    localparam [11:0] UART_RX_DATA_ADDR = 12'h010;

    logic [7:0] UART_TX_DATA_REG;
    logic       UART_CTL_REG;
    logic [1:0] UART_STATUS_REG;
    logic [7:0] UART_RX_DATA_REG;
    logic [1:0] UART_BAUD_REG;

    logic [7:0] w_rx_data, w_rx_data_reg;
    logic w_b_tick, w_tx_busy, w_rx_done;
    logic w_rx_done_reg;

    assign PREADY = (PENABLE & PSEL) ? 1'b1 : 1'b0;

    // assign PRDATA = (PADDR[11:0] == UART_CTL_ADDR)     ? {31'd0, UART_CTL_REG} :
    //                 (PADDR[11:0] == UART_BAUD_ADDR)    ? {30'd0, UART_BAUD_REG} :
    //                 (PADDR[11:0] == UART_STATUS_ADDR)  ? {30'd0, UART_STATUS_REG} :
    //                 (PADDR[11:0] == UART_TX_DATA_ADDR) ? {24'd0, UART_TX_DATA_REG} :
    //                 (PADDR[11:0] == UART_RX_DATA_ADDR) ? {24'd0, UART_RX_DATA_REG} :
    //                 32'hxxxxxxxx;

    // CPU -> UART TX(UART_TX_DATA_REG, CTL_REG, BAUD_REG)
    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            UART_TX_DATA_REG <= 8'h00;
            UART_CTL_REG     <= 1'b0;
            UART_BAUD_REG    <= 2'b00;
            w_rx_data_reg    <= 8'd0;
            w_rx_done_reg    <= 1'b0;
        end else begin
            if (w_rx_done) begin
                w_rx_done_reg <= 1'b1;
                w_rx_data_reg <= w_rx_data;
            end else if (PREADY & !PWRITE) begin
                if (PADDR[11:0] == UART_RX_DATA_ADDR) begin
                    w_rx_done_reg <= 1'b0;
                end
            end

            if (PREADY & PWRITE) begin
                case (PADDR[11:0])
                    UART_TX_DATA_ADDR:
                    UART_TX_DATA_REG <= PWDATA[7:0];  // tx_data
                    UART_CTL_ADDR: UART_CTL_REG <= PWDATA[0];  // tx_start
                    UART_BAUD_ADDR: UART_BAUD_REG <= PWDATA[1:0];  // baud_sel
                endcase
            end else begin
                UART_CTL_REG <= 0;
            end
        end
    end

    // UART RX -> CPU(STATUS_REG, UART_RX_DATA_REG)
    // always_comb begin
    //     UART_STATUS_REG = 2'b00;
    //     UART_RX_DATA_REG = 8'd0;
    //     if (PREADY & !PWRITE) begin
    //         case (PADDR[11:0])
    //             UART_STATUS_ADDR:  UART_STATUS_REG = {rx_done_reg, w_tx_busy};
    //             UART_RX_DATA_ADDR: UART_RX_DATA_REG = w_rx_data;
    //         endcase
    //     end
    // end

    always_comb begin
        PRDATA = 32'd0;
        if (PSEL && !PWRITE) begin
            case (PADDR[11:0])
                UART_CTL_ADDR:     PRDATA = {31'd0, UART_CTL_REG};
                UART_BAUD_ADDR:    PRDATA = {30'd0, UART_BAUD_REG};
                UART_STATUS_ADDR:  PRDATA = {30'd0, w_rx_done_reg, w_tx_busy};
                UART_TX_DATA_ADDR: PRDATA = {24'd0, UART_TX_DATA_REG};
                UART_RX_DATA_ADDR: PRDATA = {24'd0, w_rx_data_reg};
                default:           PRDATA = 32'd0;
            endcase
        end
    end

    uart_tx U_UART_TX (
        .clk     (PCLK),
        .rst     (PRESET),
        .tx_start(UART_CTL_REG),
        .b_tick  (w_b_tick),
        .tx_data (UART_TX_DATA_REG),
        .tx_busy (w_tx_busy),
        .tx_done (),
        .uart_tx (uart_tx)
    );

    uart_rx U_UART_RX (
        .clk    (PCLK),
        .rst    (PRESET),
        .rx     (uart_rx),
        .b_tick (w_b_tick),
        .rx_data(w_rx_data),
        .rx_done(w_rx_done)
    );

    baud_tick U_BAUD_TICK (
        .clk     (PCLK),
        .rst     (PRESET),
        .baud_sel(UART_BAUD_REG),
        .b_tick  (w_b_tick)
    );

endmodule

module uart_rx (
    input        clk,
    input        rst,
    input        rx,
    input        b_tick,
    output [7:0] rx_data,
    output       rx_done
);

    localparam IDLE = 2'd0;
    localparam START = 2'd1;
    localparam DATA = 2'd2;
    localparam STOP = 2'd3;

    // state reg
    reg [1:0] c_state, n_state;
    reg [4:0] b_tick_cnt_reg, b_tick_cnt_next;
    reg [2:0] bit_cnt_reg, bit_cnt_next;
    reg done_reg, done_next;
    reg [7:0] buf_reg, buf_next;

    assign rx_data = buf_reg;
    assign rx_done = done_reg;

    //state register
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state        <= IDLE;
            b_tick_cnt_reg <= 5'd0;
            bit_cnt_reg    <= 3'd0;
            done_reg       <= 1'b0;
            buf_reg        <= 8'd0;
        end else begin
            c_state        <= n_state;
            b_tick_cnt_reg <= b_tick_cnt_next;
            bit_cnt_reg    <= bit_cnt_next;
            done_reg       <= done_next;
            buf_reg        <= buf_next;
        end
    end

    always @(*) begin
        n_state = c_state;
        b_tick_cnt_next = b_tick_cnt_reg;
        bit_cnt_next = bit_cnt_reg;
        done_next = done_reg;
        buf_next = buf_reg;
        case (c_state)
            IDLE: begin
                b_tick_cnt_next = 5'd0;
                bit_cnt_next    = 3'd0;
                done_next       = 1'b0;
                if (b_tick && !rx) begin
                    buf_next = 8'd0;
                    n_state  = START;
                end
            end
            START: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 7) begin
                        b_tick_cnt_next = 0;
                        n_state = DATA;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            DATA: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 0;
                        buf_next = {rx, buf_reg[7:1]};
                        if (bit_cnt_reg == 7) begin
                            n_state = STOP;
                        end else begin
                            bit_cnt_next = bit_cnt_reg + 1;
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            STOP: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        n_state   = IDLE;
                        done_next = 1'b1;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
        endcase
    end
endmodule

module uart_tx (
    input        clk,
    input        rst,
    input        tx_start,
    input        b_tick,
    input  [7:0] tx_data,
    output       tx_busy,
    output       tx_done,
    output       uart_tx
);

    localparam IDLE = 2'd0;
    localparam START = 2'd1;
    localparam DATA = 2'd2;
    localparam STOP = 2'd3;

    // state reg
    reg [1:0] c_state, n_state;
    reg tx_reg, tx_next;  //for output SL
    // bit_cnt
    reg [2:0] bit_cnt_reg, bit_cnt_next;
    //baud_tick_counter
    reg [3:0] b_tick_cnt_reg, b_tick_cnt_next;
    // busy, done
    reg busy_reg, busy_next, done_reg, done_next;
    // data_in_buf
    reg [7:0] data_in_buf_reg, data_in_buf_next;

    assign uart_tx = tx_reg;
    assign tx_busy = busy_reg;
    assign tx_done = done_reg;

    // state register SL
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state         <= IDLE;
            tx_reg          <= 1'b1;
            bit_cnt_reg     <= 4'd0;
            b_tick_cnt_reg  <= 4'd0;
            busy_reg        <= 0;
            done_reg        <= 0;
            data_in_buf_reg <= 8'd0;
        end else begin
            c_state         <= n_state;
            tx_reg          <= tx_next;
            bit_cnt_reg     <= bit_cnt_next;
            b_tick_cnt_reg  <= b_tick_cnt_next;
            busy_reg        <= busy_next;
            done_reg        <= done_next;
            data_in_buf_reg <= data_in_buf_next;
        end
    end

    //next CL
    always @(*) begin
        n_state          = c_state;
        tx_next          = tx_reg;
        bit_cnt_next     = bit_cnt_reg;
        b_tick_cnt_next  = b_tick_cnt_reg;
        busy_next        = busy_reg;
        done_next        = done_reg;
        data_in_buf_next = data_in_buf_reg;
        case (c_state)
            IDLE: begin
                tx_next = 1'b1;
                bit_cnt_next = 3'd0;
                b_tick_cnt_next = 4'h0;
                busy_next = 1'b0;
                done_next = 1'b0;
                if (tx_start) begin
                    n_state          = START;
                    busy_next        = 1'b1;
                    data_in_buf_next = tx_data;
                end
            end

            START: begin
                tx_next = 0;
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        n_state = DATA;
                        b_tick_cnt_next = 4'h0;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            DATA: begin
                tx_next = data_in_buf_reg[0];
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        if (bit_cnt_reg == 7) begin
                            b_tick_cnt_next = 4'h0;
                            n_state = STOP;
                        end else begin
                            b_tick_cnt_next = 4'h0;
                            bit_cnt_next = bit_cnt_reg + 1;
                            data_in_buf_next = {1'b0, data_in_buf_reg[7:1]};
                            n_state = DATA;
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            STOP: begin
                tx_next = 1;
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        n_state = IDLE;
                        done_next = 1'b1;
                        b_tick_cnt_next = 4'h0;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
        endcase
    end
endmodule

module baud_tick (
    input              clk,
    input              rst,
    input        [1:0] baud_sel,
    output logic       b_tick
);
    // 100MHz/9600*16 -> count 해야 할 값
    parameter BAUDRATE_9600 = (9600 * 16);
    parameter BAUDRATE_19200 = (19200 * 16);
    parameter BAUDRATE_115200 = (115200 * 16);

    parameter F_count_9600 = 100_000_000 / BAUDRATE_9600;  // 651마다 count
    parameter F_count_19200 = 100_000_000 / BAUDRATE_19200;
    parameter F_count_115200 = 100_000_000 / BAUDRATE_115200;

    // localparam F_count_9600   = 651;
    // localparam F_count_19200  = 325;
    // localparam F_count_115200 = 54;

    // reg for counter(비트 수는 제일 큰 거 하나로 할당)
    reg [$clog2(F_count_9600)-1 : 0] counter_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            b_tick <= 0;
        end else begin
            counter_reg <= counter_reg + 1'b1;
            b_tick <= 0;
            case (baud_sel)
                2'b01: begin
                    if (counter_reg >= (F_count_19200 - 1)) begin
                        counter_reg <= 0;
                        b_tick <= 1'b1;
                    end else begin
                        b_tick <= 1'b0;
                    end
                end
                2'b10: begin
                    if (counter_reg >= (F_count_115200 - 1)) begin
                        counter_reg <= 0;
                        b_tick <= 1'b1;
                    end else begin
                        b_tick <= 1'b0;
                    end
                end
                default: begin
                    if (counter_reg >= (F_count_9600 - 1)) begin
                        counter_reg <= 0;
                        b_tick <= 1'b1;
                    end else begin
                        b_tick <= 1'b0;
                    end
                end
            endcase
        end
    end
endmodule
