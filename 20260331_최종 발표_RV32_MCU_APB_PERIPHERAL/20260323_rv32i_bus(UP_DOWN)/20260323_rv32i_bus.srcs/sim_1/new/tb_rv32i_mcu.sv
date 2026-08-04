`timescale 1ns / 1ps

module tb_rv32i_mcu ();
    logic clk, rst_n;
    logic [15:0] gpo;
    wire  [15:0] gpio; // 스위치 입력용 (삼태 버퍼나 외부 할당 필요)
    logic [ 3:0] fnd_digit;
    logic [ 7:0] fnd_data;
    logic rx, tx;      // MCU 입장에서 rx는 PC의 tx입니다.

    // 19200bps를 위한 비트 타임 (1/19200 * 10^9 ns)
    localparam BIT_TIME = 52083; 

    rv32i_mcu dut (
        .clk(clk),
        .rst_n(rst_n),
        .gpo(gpo),
        .gpio(gpio),
        .fnd_digit(fnd_digit),
        .fnd_data(fnd_data),
        .rx(tx), // PC의 tx가 MCU의 rx로 들어감
        .tx(rx)
    );

    // 100MHz 클럭 가정 (10ns 주기)
    always #5 clk = ~clk;

    // UART 송신용 테스크 (PC 역할)
    task uart_send(input [7:0] data);
        integer i;
        begin
            tx = 0; // Start Bit
            #(BIT_TIME);
            for (i = 0; i < 8; i = i + 1) begin
                tx = data[i]; // Data Bits (LSB first)
                #(BIT_TIME);
            end
            tx = 1; // Stop Bit
            #(BIT_TIME);
        end
    endtask

    // 시뮬레이션 시나리오
    initial begin
        // 초기 설정
        clk = 0;
        rst_n = 1;
        tx = 1; // Idle 상태는 High
        
        // 리셋 해제
        @(negedge clk);
        rst_n = 0;
        repeat (10) @(negedge clk);
        rst_n = 1;

        // MCU 초기화 및 "init" 출력 대기
        repeat (100) @(negedge clk);

        // --- 시나리오 시작 ---
        
        // 1. 's' 명령 전송 (ASCII 0x73)
        uart_send(8'h73);
        #(BIT_TIME * 2); // 문자 사이 약간의 여유

        // 2. 비밀번호 '4', '3', '2', '1' 전송 (ASCII 0x31~0x34)
        uart_send(8'h34);
        uart_send(8'h33);
        uart_send(8'h32);
        uart_send(8'h31);
        #(BIT_TIME * 5); // MCU가 "donE"을 띄울 시간 대기

        // 3. 'i' 명령 전송 (판정 모드)
        uart_send(8'h69);

        // 결과 관찰을 위한 넉넉한 대기
        repeat (10000) @(negedge clk);
        $stop;
    end
endmodule




// module tb_rv32i ();
//     logic clk, rst_n; 
//     logic [3:0] fnd_digit;
//     logic [7:0] fnd_data;
//     logic rx, tx;

//     // 100MHz 클럭 기준, 9600bps 통신 시 1비트당 필요한 클럭 수 (100,000,000 / 9600)
//     localparam CLKS_PER_BIT = 10416;

//     rv32i_mcu dut (
//         .clk(clk),
//         .rst_n(rst_n),
//         .fnd_digit(fnd_digit),
//         .fnd_data(fnd_data),
//         .rx(rx),
//         .tx(tx)
//     );

//     // 100MHz 클럭 생성 (주기 10ns)
//     always #5 clk = ~clk; 

//     // -----------------------------------------------------------------
//     // [1] 가상의 외부 장치 (RX로 데이터를 쏴주는 Task)
//     // -----------------------------------------------------------------
//     task uart_send_byte(input [7:0] data);
//         integer i;
//         begin
//             // Start Bit
//             rx = 1'b0; 
//             repeat(CLKS_PER_BIT) @(posedge clk);

//             // Data Bits (LSB부터 전송)
//             for (i = 0; i < 8; i = i + 1) begin
//                 rx = data[i];
//                 repeat(CLKS_PER_BIT) @(posedge clk);
//             end

//             // Stop Bit
//             rx = 1'b1; 
//             repeat(CLKS_PER_BIT) @(posedge clk);

//             $display("[TB -> MCU] Sent Data: 8'h%h", data);
//         end
//     endtask

//     // -----------------------------------------------------------------
//     // [2] TX 수신 모니터 (MCU가 뱉어내는 tx 데이터를 분석하여 출력)
//     // -----------------------------------------------------------------
//     logic [7:0] tb_rx_data;
//     initial begin
//         forever begin
//             // 평소에는 1(High) 상태이다가, 0(Start bit)으로 떨어지는 순간 대기 해제
//             @(negedge tx); 

//             // 타이밍 핵심: 비트의 정중앙으로 이동하기 위해 0.5 비트시간 대기
//             repeat (CLKS_PER_BIT / 2) @(posedge clk);

//             // 정말 Start bit가 맞는지 다시 확인 (노이즈 필터링 역할)
//             if (tx == 1'b0) begin
//                 // Data Bits 8개 읽기
//                 for (int i = 0; i < 8; i++) begin
//                     repeat (CLKS_PER_BIT) @(posedge clk); // 1비트 시간만큼 건너뜀 (다음 비트의 정중앙)
//                     tb_rx_data[i] = tx; // 현재 tx 핀의 상태를 저장
//                 end

//                 // Stop Bit 위치로 이동
//                 repeat (CLKS_PER_BIT) @(posedge clk); 

//                 $display("[MCU -> TB] Received Data: 8'h%h (%c)", tb_rx_data, tb_rx_data);
//             end
//         end
//     end

//     // -----------------------------------------------------------------
//     // [3] 메인 테스트 시나리오
//     // -----------------------------------------------------------------
//     initial begin
//         clk = 0;
//         rst_n = 0;
//         rx = 1'b1; // UART Idle 상태

//         @(negedge clk);
//         rst_n = 1;

//         // 시스템 초기화 대기 (CPU가 부팅되고 레지스터 세팅할 시간)
//         repeat(15000) @(posedge clk);

//         // 테스트벤치에서 MCU로 문자 'A' (8'h41) 전송
//         uart_send_byte(8'h41);

//         // 연달아서 문자 'B' (8'h42) 전송
//         uart_send_byte(8'h42);

//         // MCU가 응답(TX)할 때까지 넉넉하게 대기
//         repeat(500000) @(posedge clk);

//         $display("Simulation Finished.");
//         $stop;
//     end

// endmodule

// /*
// `timescale 1ns / 1ps

// module tb_rv32i ();
//     logic clk, rst_n; 
//     logic [7:0] gpi; 
//     wire  [7:0] gpo; 
//     wire  [15:0] gpio; 
//     logic rx, tx;

//     rv32i_mcu dut (
//         .clk(clk),
//         .rst_n(rst_n),
//         .gpi(gpi),
//         .gpo(gpo),
//         .gpio(gpio),
//         .rx(rx),
//         .tx(tx)
//     );

//     always #5 clk = ~clk;

//     // [핵심] 양방향 포트(GPIO) 외부 신호 인가
//     // 하위 8비트[7:0]는 C 코드에서 입력으로 설정했으므로 테스트벤치에서 값(0x55)을 줍니다.
//     // 상위 8비트[15:8]는 출력으로 설정했으므로 테스트벤치에서 선을 끊어줍니다(High-Z, ZZ).
//     // 이렇게 해야 하드웨어 충돌(Short)이 발생하지 않습니다.
//     assign gpio[7:0]  = 8'h55;
//     assign gpio[15:8] = 8'hZZ;

//     initial begin
//         clk = 0;
//         rst_n = 0;
//         gpi = 8'h00;

//         @(negedge clk);
//         @(negedge clk);
//         rst_n = 1;

//         // GPI 포트에 테스트 값(0xAA) 인가
//         gpi = 8'hAA;

//         // 코드가 한 번만 순차적으로 실행되므로 대기 시간을 대폭 줄일 수 있습니다.
//         // 200클럭이면 BRAM, GPI, GPO, GPIO 검증을 모두 마치고 시스템 정지 루프에 안착합니다.
//         repeat(200) @(negedge clk);
//         $stop;
//     end
// endmodule
// */
// /*
// `timescale 1ns / 1ps
// module tb_rv32i ();
//     logic clk, rst_n; 
// //    logic [7:0] gpi; 
// //    wire  [7:0] gpo; 
// //    wire  [15:0] gpio; 
//     logic [3:0] fnd_digit;
//     logic [7:0] fnd_data;
//     logic rx, tx;

//     rv32i_mcu dut (
//         .clk(clk),
//         .rst_n(rst_n),
//        // .gpi(gpi),
//        // .gpo(gpo),
//        // .gpio(gpio),
//         .fnd_digit(fnd_digit),
//         .fnd_data(fnd_data),
//         .rx(rx),
//         .tx(tx)
//     );

//     always #5 clk = ~clk;
//     // ... 포트 및 모듈 인스턴스화 생략 (기존과 동일하게 유지) ...

//     initial begin
//         clk = 0;
//         rst_n = 0;
//         rx = 1'b1; // UART 통신선의 기본 상태는 1(High)입니다.

//         @(negedge clk);
//         rst_n = 1;

//         // [1] TX 송신이 끝날 때까지 넉넉하게 기다려 줍니다.
//         // 9600bps 기준 1바이트 전송에 약 10.4만 클럭 소요 (여유 있게 15만 클럭 대기)
//         repeat(150000) @(negedge clk);

//         // [2] 외부 장치(테스트벤치)가 CPU로 데이터 0xA5 (1010_0101)를 쏘는 과정 모사
//         // 1비트당 10416 클럭을 유지해야 9600bps 속도에 맞습니다.
//         rx = 1'b0; repeat(10416) @(negedge clk); // Start Bit (0)

//         rx = 1'b1; repeat(10416) @(negedge clk); // Bit 0 (1)
//         rx = 1'b0; repeat(10416) @(negedge clk); // Bit 1 (0)
//         rx = 1'b1; repeat(10416) @(negedge clk); // Bit 2 (1)
//         rx = 1'b0; repeat(10416) @(negedge clk); // Bit 3 (0)
//         rx = 1'b0; repeat(10416) @(negedge clk); // Bit 4 (0)
//         rx = 1'b1; repeat(10416) @(negedge clk); // Bit 5 (1)
//         rx = 1'b0; repeat(10416) @(negedge clk); // Bit 6 (0)
//         rx = 1'b1; repeat(10416) @(negedge clk); // Bit 7 (1)

//         rx = 1'b1; repeat(10416) @(negedge clk); // Stop Bit (1)

//         // [3] CPU가 수신 완료를 인지하고 FND를 업데이트할 시간 대기
//         repeat(5000) @(negedge clk);
//         $stop;
//     end
// endmodule
// */
