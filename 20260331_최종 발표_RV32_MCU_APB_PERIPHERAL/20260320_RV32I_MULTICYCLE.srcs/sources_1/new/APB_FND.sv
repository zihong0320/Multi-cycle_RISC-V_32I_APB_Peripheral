`timescale 1ns / 1ps

module APB_FND (
    // BUS Global signal
    input PCLK,
    input PRESET,

    // APB Interface Signal
    input        [31:0] PADDR,
    input        [31:0] PWDATA,
    input               PENABLE,
    input               PWRITE,
    input               PSEL,
    output logic [31:0] PRDATA,
    output logic        PREADY,
    //output logic [15:0] FND_OUT,
    output       [ 3:0] fnd_digit,
    output       [ 7:0] fnd_data
);
    localparam [11:0] FND_CTL_ADDR = 12'h000;
    localparam [11:0] FND_ODATA_ADDR = 12'h004;
    logic [15:0] FND_CTL_REG, FND_ODATA_REG, FND_OUT;

    assign PREADY = (PENABLE & PSEL) ? 1'b1 : 1'b0;

    assign PRDATA = (PADDR[11:0] == FND_CTL_ADDR)   ? {16'h0000, FND_CTL_REG} :
                    (PADDR[11:0] == FND_ODATA_ADDR) ? {16'h0000, FND_ODATA_REG} : 32'hxxxxxxxx;

    always_ff @(posedge PCLK, posedge PRESET) begin : blockName
        if (PRESET) begin
            FND_CTL_REG   <= 16'h0000;
            FND_ODATA_REG <= 16'h0000;
        end else begin
            if (PREADY & PWRITE) begin
                case(PADDR[11:0])
                    FND_CTL_ADDR   : FND_CTL_REG   <= PWDATA[15:0];
                    FND_ODATA_ADDR : FND_ODATA_REG <= PWDATA[15:0];
                endcase
            end
        end
    end

    genvar i;
    generate
        for (i = 0; i < 16; i++) begin
            assign FND_OUT[i] = FND_ODATA_REG[i];
        end
    endgenerate

    fnd_controller U_FND_CONTROLLER (
        .clk      (PCLK),
        .reset    (PRESET),
        .in_data  (FND_OUT),
        .fnd_digit(fnd_digit),
        .fnd_data (fnd_data)
    );


endmodule

module fnd_controller (
    input         clk,
    input         reset,
    input  [15:0] in_data,
    output [ 3:0] fnd_digit,
    output [ 7:0] fnd_data
);
    wire [3:0] w_digit_1, w_digit_10, w_digit_100, w_digit_1000, w_mux_4x1_out;
    wire [1:0] w_digit_sel;
    wire w_1khz;

    digit_splitter U_DIGIT_SPL (
        .in_data   (in_data),
        .digit_1   (w_digit_1),    // 0~9 -> 4bit
        .digit_10  (w_digit_10),   // 0~9 -> 4bit
        .digit_100 (w_digit_100),  // 0~9 -> 4bit
        .digit_1000(w_digit_1000)  // 0~9 -> 4bit
    );

    clk_div U_CLK_DIV (
        .clk   (clk),
        .reset (reset),
        .o_1khz(w_1khz)
    );

    counter_4 U_COUNTER_4 (
        .clk      (w_1khz),
        .reset    (reset),
        .digit_sel(w_digit_sel)
    );

    decoder_2x4 U_DECODER_2x4 (
        .digit_sel(w_digit_sel),
        .fnd_digit(fnd_digit)
    );

    mux_4x1 U_Mux_4x1 (
        .sel       (w_digit_sel),
        .digit_1   (w_digit_1),
        .digit_10  (w_digit_10),
        .digit_100 (w_digit_100),
        .digit_1000(w_digit_1000),
        .mux_out   (w_mux_4x1_out)
    );

    bcd U_BCD (
        .bcd(w_mux_4x1_out),
        .fnd_data(fnd_data)
    );

endmodule

module clk_div (
    input      clk,
    input      reset,
    output reg o_1khz
);
    //reg [16:0] counter_r;
    reg [$clog2(100_000):0] counter_r;


    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_r <= 0;
            o_1khz    <= 1'b0;
        end else begin
            if (counter_r == 99_999) begin
                counter_r <= 0;
                o_1khz    <= 1'b1;
                //o_1khz <= ~o_1khz; -> duty ratio가 1:1
            end else begin
                counter_r <= counter_r + 1;
                o_1khz    <= 1'b0;
            end
        end
    end

endmodule

module counter_4 (
    input        clk,
    input        reset,
    output [1:0] digit_sel
);

    reg [1:0] counter_r;

    assign digit_sel = counter_r;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            //init counter_r
            counter_r <= 0;
        end else begin
            //to do
            counter_r <= counter_r + 1;
        end
    end

endmodule

module decoder_2x4 (
    input      [1:0] digit_sel,
    output reg [3:0] fnd_digit
);

    always @(*) begin
        case (digit_sel)
            2'b00: fnd_digit = 4'b1110;
            2'b01: fnd_digit = 4'b1101;
            2'b10: fnd_digit = 4'b1011;
            2'b11: fnd_digit = 4'b0111;
        endcase
    end

endmodule

module mux_4x1 (
    input      [1:0] sel,
    input      [3:0] digit_1,
    input      [3:0] digit_10,
    input      [3:0] digit_100,
    input      [3:0] digit_1000,
    output reg [3:0] mux_out
);

    always @(*) begin
        case (sel)
            2'b00: mux_out = digit_1;
            2'b01: mux_out = digit_10;
            2'b10: mux_out = digit_100;
            2'b11: mux_out = digit_1000;
        endcase
    end

endmodule

module digit_splitter (
    input  [15:0] in_data,
    output [ 3:0] digit_1,    // 0~9 -> 4bit
    output [ 3:0] digit_10,   // 0~9 -> 4bit
    output [ 3:0] digit_100,  // 0~9 -> 4bit
    output [ 3:0] digit_1000  // 0~9 -> 4bit
);
    // assign digit_1    = in_data % 10;
    // assign digit_10   = (in_data/10) % 10;
    // assign digit_100  = (in_data/100) % 10;
    // assign digit_1000 = (in_data/1000) % 10;

    integer i;
    // 16비트 입력 데이터와 4비트씩의 결과값을 담기 위한 32비트 레지스터
    reg [31:0] temp; 

    always @(*) begin
        // 1. 초기화: 상위 16비트는 0, 하위 16비트에 입력 데이터 배치
        temp = {16'b0, in_data};

        // 2. Double Dabble 알고리즘 (16회 반복)
        for (i = 0; i < 16; i = i + 1) begin
            
            // 각 4비트 마디(BCD Digit)가 5 이상이면 3을 더함
            if (temp[19:16] >= 5) temp[19:16] = temp[19:16] + 3; // 1의 자리
            if (temp[23:20] >= 5) temp[23:20] = temp[23:20] + 3; // 10의 자리
            if (temp[27:24] >= 5) temp[27:24] = temp[27:24] + 3; // 100의 자리
            if (temp[31:28] >= 5) temp[31:28] = temp[31:28] + 3; // 1000의 자리

            // 전체 비트를 왼쪽으로 1비트 시프트
            temp = temp << 1;
        end
    end

    // 3. 최종 계산된 값을 출력 포트에 할당
    assign digit_1    = temp[19:16];
    assign digit_10   = temp[23:20];
    assign digit_100  = temp[27:24];
    assign digit_1000 = temp[31:28];

endmodule


module bcd (
    input      [3:0] bcd,
    output reg [7:0] fnd_data
);

    always @(bcd) begin
        case (bcd)
            4'd0:    fnd_data = 8'hC0;
            4'd1:    fnd_data = 8'hF9;
            4'd2:    fnd_data = 8'hA4;
            4'd3:    fnd_data = 8'hB0;
            4'd4:    fnd_data = 8'h99;
            4'd5:    fnd_data = 8'h92;
            4'd6:    fnd_data = 8'h82;
            4'd7:    fnd_data = 8'hF8;
            4'd8:    fnd_data = 8'h80;
            4'd9:    fnd_data = 8'h90;
            default: fnd_data = 8'hFF;
        endcase
    end

endmodule
