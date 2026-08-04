`timescale 1ns / 1ps

module UART (
    input logic        pclk,
    input logic        presetn,
    input logic [31:0] paddr,
    input logic [31:0] pwdata,
    input logic        pwrite,
    input logic        psel,
    input logic        penable,

    output logic [31:0] prdata,
    output logic        pready,

    input  logic i_uart_rx,
    output logic o_uart_tx
);

    // localparam [11:0] UART_TX_DATA_ADDR = 12'h000;
    // localparam [11:0] UART_CTL_ADDR = 12'h004;
    // localparam [11:0] UART_STATUS_ADDR = 12'h008;
    // localparam [11:0] UART_RX_DATA_ADDR = 12'h00C;
    // localparam [11:0] UART_BAUD_ADDR = 12'h010;

    localparam [11:0] UART_CTL_ADDR = 12'h000;
    localparam [11:0] UART_BAUD_ADDR = 12'h004;
    localparam [11:0] UART_STATUS_ADDR = 12'h008;
    localparam [11:0] UART_TX_DATA_ADDR = 12'h00c;
    localparam [11:0] UART_RX_DATA_ADDR = 12'h010;

    logic [7:0] tx_data_reg;  // 보낼 데이터 받아둠
    logic       ctl_tx_start;  // 송신 시작 방아쇠
    logic [7:0] rx_data_reg;  // 외부 들어온 데이터 금고
    logic [1:0] baud_reg;  // 통신속도 결정

    logic       status_rx_done;  // 데이터 도착 알림 신호 -> cpu에게
    logic       status_w_tx_busy;  // 현재 송신중임 알리는 신호

    // 하위 모듈에서 상위 모듈로 연결할 때에는 항상 wire가 필요하다!!!!
    logic       w_rx_done;  // 나 데이터 다 받음!
    logic [7:0] w_rx_data;  // 실제 수신 데이터선

    assign pready = (penable & psel) ? 1'b1 : 1'b0;

    // 데이터를 안전하게 가둬둘 때(Write)는 클럭에 맞춰 always_ff를 쓰고, 
    // 가둬둔 데이터를 지연 없이 보여줄 때(Read)는 always_comb를 씁니다람쥐.
    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            tx_data_reg    <= 8'h00;
            ctl_tx_start   <= 1'b0;
            baud_reg       <= 2'b00;
            rx_data_reg    <= 8'h00;
            status_rx_done <= 1'b0;
        end else begin

            if (psel && penable && pwrite) begin
                case (paddr[11:0])
                    UART_TX_DATA_ADDR: tx_data_reg <= pwdata[7:0];
                    UART_BAUD_ADDR:    baud_reg <= pwdata[1:0];
                    UART_CTL_ADDR:     ctl_tx_start <= pwdata[0];
                endcase
            end else begin
                ctl_tx_start <= 1'b0;
            end

            if (w_rx_done) begin
                rx_data_reg <= w_rx_data;
                status_rx_done <= 1'b1;
            end 
            else if (psel && penable && !pwrite && (paddr[11:0] == UART_RX_DATA_ADDR)) begin
                status_rx_done <= 1'b0;
            end

        end
    end

    always_comb begin
        prdata = 32'h0000_0000;
        // read일 때는 mux가 있어 조건문을 없애도 선이 중첩되는 일이 없음 -> 타이밍을 조금 여유롭게 주자!
        // read는 조합논리이기에 미리 가져가도 상관 x, write는 순차논리이기에 무조건 일치하는 순간에만 가져가야함.
        if (psel && !pwrite && penable) begin
            case (paddr[11:0])
                UART_STATUS_ADDR: prdata = {status_rx_done, 30'h0, status_w_tx_busy};
                UART_RX_DATA_ADDR: prdata = {24'h0, rx_data_reg};
                UART_BAUD_ADDR: prdata = {30'h0, baud_reg};
            endcase
        end
    end

    uart_top U_UART_TOP (
        .clk       (pclk),
        .reset     (~presetn),
        .rx        (i_uart_rx),
        .tx        (o_uart_tx),
        .i_baud_sel(baud_reg),          // baud_reg
        .i_tx_data (tx_data_reg),
        .i_tx_start(ctl_tx_start),
        .o_rx_data (w_rx_data),
        .o_rx_done (w_rx_done),
        .o_tx_busy (status_w_tx_busy),
        .o_tx_done ()
    );

endmodule

`timescale 1ns / 1ps

module uart_top (
    input        clk,
    input        reset,
    input        rx,
    output       tx,
    input  [1:0] i_baud_sel,
    input        i_tx_start,
    input  [7:0] i_tx_data,
    output [7:0] o_rx_data,
    output       o_rx_done,
    output       o_tx_busy,
    output       o_tx_done
);

    wire w_b_tick, w_rx_done;
    wire [7:0] w_rx_data;

    assign o_rx_data = w_rx_data;
    assign o_rx_done = w_rx_done;

    uart_rx U_UART_RX (
        .clk(clk),
        .reset(reset),
        .rx(rx),
        .b_tick(w_b_tick),
        .rx_data(w_rx_data),
        .rx_done(w_rx_done)
    );

    uart_tx U_UART_TX (
        .clk(clk),
        .reset(reset),
        .tx_start(i_tx_start),
        .b_tick(w_b_tick),
        .tx_data(i_tx_data),
        .tx_busy(o_tx_busy),
        .tx_done(o_tx_done),
        .tx(tx)
    );

    baud_tick U_BAUD_TICK (
        .clk(clk),
        .reset(reset),
        .baud_sel(i_baud_sel),
        .b_tick(w_b_tick)
    );
endmodule

module uart_rx (
    input        clk,
    input        reset,
    input        rx,
    input        b_tick,
    output [7:0] rx_data,
    output       rx_done
);

    localparam IDLE = 2'd0, START = 2'd1, DATA = 2'd2, STOP = 2'd3;
    reg [1:0] current_state, next_state;
    reg [4:0] b_tick_cnt_reg, b_tick_cnt_next;
    reg [2:0] bit_cnt_next, bit_cnt_reg;
    reg done_reg, done_next;
    reg [7:0] buf_reg, buf_next;

    assign rx_data = buf_reg;
    assign rx_done = done_reg;

    // state register
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            current_state  <= 2'd0;
            b_tick_cnt_reg <= 5'd0;
            bit_cnt_reg    <= 3'd0;
            done_reg       <= 1'b0;
            buf_reg        <= 8'd0;
        end else begin
            current_state  <= next_state;
            b_tick_cnt_reg <= b_tick_cnt_next;
            bit_cnt_reg    <= bit_cnt_next;
            done_reg       <= done_next;
            buf_reg        <= buf_next;
        end
    end

    // next, output
    always @(*) begin
        next_state      = current_state;
        b_tick_cnt_next = b_tick_cnt_reg;
        bit_cnt_next    = bit_cnt_reg;
        done_next       = done_reg;
        buf_next        = buf_reg;
        case (current_state)
            IDLE: begin
                done_next       = 1'b0;
                b_tick_cnt_next = 5'd0;
                bit_cnt_next    = 3'd0;
                if (b_tick & !rx) begin
                    buf_next   = 8'd0;
                    next_state = START;
                end
            end
            START: begin
                if (b_tick)
                    if (b_tick_cnt_reg == 7) begin
                        b_tick_cnt_next = 0;
                        next_state = DATA;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
            end
            DATA: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 0;
                        buf_next = {rx, buf_reg[7:1]};
                        if (bit_cnt_reg == 7) begin
                            next_state = STOP;
                        end else begin
                            bit_cnt_next = bit_cnt_reg + 1;
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            STOP: begin
                if (b_tick)
                    if (b_tick_cnt_reg == 15) begin
                        next_state = IDLE;
                        done_next  = 1'b1;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
            end
        endcase
    end

endmodule

module uart_tx (
    input        clk,
    input        reset,
    input        tx_start,
    input        b_tick,
    input  [7:0] tx_data,
    output       tx_busy,
    output       tx_done,
    output       tx
);

    localparam IDLE = 2'd0, START = 2'd1;
    localparam DATA = 2'd2, STOP = 2'd3;

    //state reg
    reg [1:0] current_state, next_state;
    reg tx_reg, tx_next;  // for output SL
    reg [2:0] bit_cnt_reg, bit_cnt_next;
    //baud tick counter
    reg [3:0] b_tick_cnt_reg, b_tick_cnt_next;
    // busy, done
    reg busy_reg, busy_next, done_reg, done_next;
    // data_in_buf
    reg [7:0] data_in_buf_reg, data_in_buf_next;

    assign tx = tx_reg;
    assign tx_busy = busy_reg;
    assign tx_done = done_reg;

    //state register SL
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            current_state   <= IDLE;
            tx_reg          <= 1'b1;
            bit_cnt_reg     <= 1'b0;
            b_tick_cnt_reg  <= 4'h0;
            busy_reg        <= 1'b0;
            done_reg        <= 1'b0;
            data_in_buf_reg <= 8'h00;
        end else begin
            current_state   <= next_state;
            tx_reg          <= tx_next;
            bit_cnt_reg     <= bit_cnt_next;
            b_tick_cnt_reg  <= b_tick_cnt_next;
            busy_reg        <= busy_next;
            done_reg        <= done_next;
            data_in_buf_reg <= data_in_buf_next;
        end
    end

    // next CL
    always @(*) begin
        next_state       = current_state;
        tx_next          = tx_reg;
        bit_cnt_next     = bit_cnt_reg;
        b_tick_cnt_next  = b_tick_cnt_reg;
        busy_next        = busy_reg;
        done_next        = done_reg;
        data_in_buf_next = data_in_buf_reg;
        case (current_state)
            IDLE: begin
                tx_next         = 1'b1;
                bit_cnt_next    = 1'b0;
                b_tick_cnt_next = 4'h0;
                busy_next       = 1'b0;
                done_next       = 1'b0;
                if (tx_start) begin
                    next_state       = START;
                    busy_next        = 1'b1;
                    data_in_buf_next = tx_data;
                end
            end
            START: begin
                tx_next = 1'b0;
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        next_state = DATA;
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
                            next_state = STOP;
                        end else begin
                            b_tick_cnt_next = 4'h0;
                            bit_cnt_next = bit_cnt_reg + 1;
                            data_in_buf_next = {1'b0, data_in_buf_reg[7:1]};
                            next_state = DATA;
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            STOP: begin
                tx_next = 1'b1;
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        done_next  = 1'b1;
                        next_state = IDLE;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
        endcase
    end

endmodule

module baud_tick (
    input            clk,
    input            reset,
    input      [1:0] baud_sel,
    output reg       b_tick
);

    localparam MAX_9600 = (100_000_000 / (9600 * 16)) - 1;  // 약 650
    localparam MAX_19200 = (100_000_000 / (19200 * 16)) - 1;  // 약 324
    localparam MAX_115200 = (100_000_000 / (115200 * 16)) - 1;  // 약 53

    reg [31:0] f_count_limit;
    reg [31:0] counter_reg;

    always @(*) begin
        case (baud_sel)
            2'b00:   f_count_limit = MAX_9600;
            2'b01:   f_count_limit = MAX_19200;
            2'b10:   f_count_limit = MAX_115200;
            default: f_count_limit = MAX_9600;
        endcase
    end

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_reg <= 0;
            b_tick <= 1'b0;
        end else begin
            if (counter_reg >= f_count_limit) begin
                counter_reg <= 0;
                b_tick <= 1'b1;
            end else begin
                counter_reg <= counter_reg + 1;
                b_tick <= 1'b0;
            end
        end
    end
endmodule
