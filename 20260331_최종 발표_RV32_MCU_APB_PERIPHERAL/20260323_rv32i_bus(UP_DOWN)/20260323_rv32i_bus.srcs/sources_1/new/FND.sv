`timescale 1ns / 1ps

module FND (
    input logic        pclk,
    input logic        presetn,
    input logic [31:0] paddr,
    input logic [31:0] pwdata,
    input logic        pwrite,
    input logic        psel,
    input logic        penable,

    output logic [31:0] prdata,
    output logic        pready,

    output logic [3:0] o_fnd_digit,
    output logic [7:0] o_fnd_data
);

    localparam [11:0] FND_CTL_ADDR = 12'h000;
    localparam [11:0] FND_DATA_ADDR = 12'h004;

    logic [31:0] fnd_ctl_reg;
    logic [31:0] fnd_data_reg;

    assign pready = (penable & psel) ? 1'b1 : 1'b0;

    always_comb begin
        prdata = 32'h0000_0000;
        if (psel && !pwrite && penable) begin
            case (paddr[11:0])
                FND_CTL_ADDR:  prdata = fnd_ctl_reg;
                FND_DATA_ADDR: prdata = fnd_data_reg;
            endcase
        end
    end

    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            fnd_ctl_reg  <= 32'h0000_0000;
            fnd_data_reg <= 32'h0000_0000;
        end else begin
            if (psel && penable && pwrite) begin
                case (paddr[11:0])
                    FND_CTL_ADDR:  fnd_ctl_reg <= pwdata;
                    FND_DATA_ADDR: fnd_data_reg <= pwdata;
                endcase
            end
        end
    end

    logic [3:0] w_fnd_digit;
    logic [7:0] w_fnd_data;

    fnd_controller U_FND_CTRL (
        .clk        (pclk),
        .reset      (~presetn),
        .fnd_in_data(fnd_data_reg[15:0]),
        .fnd_digit  (w_fnd_digit),
        .fnd_data   (w_fnd_data)
    );

    assign o_fnd_digit = (fnd_ctl_reg[0]) ? w_fnd_digit : 4'b1111;
    assign o_fnd_data  = (fnd_ctl_reg[0]) ? w_fnd_data : 8'hFF;

endmodule


module fnd_controller (
    input clk,
    input reset,
    input [15:0] fnd_in_data,
    output [3:0] fnd_digit,
    output [7:0] fnd_data
);
    wire [3:0] w_digit_1, w_digit_10, w_digit_100, w_digit_1000, w_mux_4x1_out; // assign fnd_digit = 4'b1110;  // for fnd an[3:0]
    wire [1:0] w_digit_sel;
    wire w_1khz;

    digit_splitter U_DIGIT_SPL (
        .in_data(fnd_in_data),
        .digit_1(w_digit_1),
        .digit_10(w_digit_10),
        .digit_100(w_digit_100),
        .digit_1000(w_digit_1000)  /* this is 8bit so 1000 is impossible */
    );

    clk_div U_Clk_div (
        .clk(clk),
        .reset(reset),
        .o_1khz(w_1khz)
    );

    counter_4 U_Counter_4 (
        .clk(w_1khz),
        .reset(reset),
        .digit_sel(w_digit_sel)
    );

    decoder_2x4 U_Decoder_2x4 (
        .digit_sel(w_digit_sel),
        .fnd_digit(fnd_digit)
    );

    mux_4x1 U_Mux_4x1 (
        .sel(w_digit_sel),
        .digit_1(w_digit_1),
        .digit_10(w_digit_10),
        .digit_100(w_digit_100),
        .digit_1000(w_digit_1000),
        .mux_out(w_mux_4x1_out)
    );

    bcd U_BCD (
        .bcd(w_mux_4x1_out),
        .fnd_data(fnd_data)
    );
endmodule

module clk_div (
    input clk,
    input reset,
    output reg o_1khz
);

    reg [$clog2(100_000):0] counter_r;  // 100_000 Binary change / same [16:0]

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_r <= 0;  // not reser this value -> it makes x(dont care)
            o_1khz    <= 1'b0;

        end else begin
            if (counter_r == 99999) begin
                counter_r <= 0;
                o_1khz    <= 1'b1;
            end else begin
                counter_r <= counter_r + 1;
                o_1khz    <= 1'b0;
            end
        end
    end

endmodule

module counter_4 (
    input clk,
    input reset,
    output [1:0] digit_sel
);

    reg [1:0] counter_r;

    assign digit_sel = counter_r;

    always @(posedge clk, posedge reset) begin
        if (reset) begin  // if reset is 1, put 0 & same word reset == 1
            counter_r <= 0;  // sequential logic circuit use <= symbol
        end else begin  // to do 4jin counter(0123)
            counter_r <= counter_r + 1;
        end

    end

endmodule

module decoder_2x4 (  // to select to fnd digit display
    input [1:0] digit_sel,
    output reg [3:0] fnd_digit
);

    always @(digit_sel) begin
        case (digit_sel)
            2'b00: fnd_digit = 4'b1110;
            2'b01: fnd_digit = 4'b1101;
            2'b10: fnd_digit = 4'b1011;
            2'b11: fnd_digit = 4'b0111;
        endcase
    end

endmodule

module mux_4x1 (
    input [1:0] sel,
    input [3:0] digit_1,
    input [3:0] digit_10,
    input [3:0] digit_100,
    input [3:0] digit_1000,
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
    output [ 3:0] digit_1,
    output [ 3:0] digit_10,
    output [ 3:0] digit_100,
    output [ 3:0] digit_1000
);

    // assign digit_1 = in_data % 10;
    // assign digit_10 = (in_data / 10) % 10;
    // assign digit_100 = (in_data / 100) % 10;
    // assign digit_1000 = (in_data / 1000) % 10;

    assign digit_1    = in_data[3:0];  // 0~3번 비트
    assign digit_10   = in_data[7:4];  // 4~7번 비트
    assign digit_100  = in_data[11:8];  // 8~11번 비트
    assign digit_1000 = in_data[15:12];  // 12~15번 비트

endmodule

module bcd (
    input [3:0] bcd,
    output reg [7:0] fnd_data
);

    always @(bcd) begin
        case (bcd)
            4'd0: fnd_data = 8'ha1;  // 'd' (소문자)
            4'd1: fnd_data = 8'hf9;  // 'i' (소문자)
            4'd2: fnd_data = 8'hab;  // 'n' (소문자)
            4'd3: fnd_data = 8'h87;  // 't' (소문자)
            4'd4: fnd_data = 8'h92;  // 'S' (대문자)
            4'd5: fnd_data = 8'h86;  // 'E' (대문자)
            4'd6: fnd_data = 8'hFF;  // ' ' (공백 - Space)
            4'd7: fnd_data = 8'h8c;  // 'P' (대문자 P)
            4'd8: fnd_data = 8'h88;  // 'A' (대문자 A)
            // 4'd9: fnd_data = 8'h90;
            4'd10: fnd_data = 8'h89;  // 'H'
            4'd11: fnd_data = 8'hc7;  // 'L'
            4'd12: fnd_data = 8'he3;  // 'u'
            4'd13: fnd_data = 8'ha3;  // 'o'
            4'd14: fnd_data = 8'hf9;  // 'i'
            4'd15: fnd_data = 8'h90;  // 'g'
            default: fnd_data = 8'hFF;
        endcase
    end
endmodule
