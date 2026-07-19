# Multi-cycle-RISC-V-32I-APB-Peripheral


## 0. Summary
- Multi-cycle RISC-V 32I Core
- APB Bus 기반 Peripheral 설계
- C코드 알고리즘(UP, DOWN 게임) 적용


## 1. Instruction

### 1.1 RISC-V 32I

### 1.2 Multi Cycle

### 1.3 APB Interface & MMIO



## 2. Hardware Architecture

### 2.1 Overall Structure
<img width="374" height="218" alt="image" src="https://github.com/user-attachments/assets/f322731b-932f-43a7-bfa3-36ae7e3054a7" />

- Multi-cycle CPU Core
  - 명령어의 실행 과정을 Fetch, Decode, Execute, Memory, Write-Back로 분할해 순차적으로 처리하는 프로세서 코어

- APB Master
  - CPU의 Read/Write 요청을 받아 AMBA APB 버스 프로토콜 규격에 맞는 제어 신호를 생성하여 주변 장치들과의 통신

- APB Slave
  - APB Master가 생성한 제어 신호와 주소에 따라 데이터 저장, 외부 출력 등을 수행하고 결과를 Master에게 응답



### 2.2 Core
<img width="357" height="226" alt="image" src="https://github.com/user-attachments/assets/e44876f7-5a69-414c-8223-674ca01a2b95" />

- 5-stage
  - IF : 메모리에서 명령어를 Fetch
  - ID : 명령어 해석, 레지스터에서 값 가져옴 
  - EX : ALU에서 연산 실행
  - MEM : DATA MEM에 값을 쓰거나 저장
  - WB : 결과값을 다시 레지스터에 저장

- Single-cycle -> Multi-cycle 장점
  - Instruction 실행 시, 한 사이클 만에 처리하기 힘든 복잡한 명령어(LW, SW)의 실행 과정을 분할하여 Critical Path를 단축 
  - 이를 통해, 클럭 주기를 짧게, 즉, 최대 동작 주파수를 크게 설정 가능



### 2.3 APB
<img width="232" height="226" alt="image" src="https://github.com/user-attachments/assets/2fed3dda-3280-499e-a6b5-083db2a7a840" />



### 2.4 MMIO
<img width="347" height="175" alt="image" src="https://github.com/user-attachments/assets/d3039d7c-be52-4a83-91f7-b26d4125885f" />




## 3. Result

### 3.1 FPGA
<img width="364" height="196" alt="image" src="https://github.com/user-attachments/assets/ee4b55bf-0558-46dd-b791-3201c5d7962c" />
<C 코드(UP, DOWN game) 적용 사진>


- C code(UP, DOWN 게임)
  - UART로 4자리 정답값 설정 후 ‘s’ send
  - Switch로 예측값 설정
  - UART로 ‘i’ send
  - 예측값과 정답값을 비교
  - FND에 ‘PASS’, ‘LOW’, ‘HIGH’ 출력





<동영상>


### 3.2 IMPLEMENTATION
<img width="296" height="141" alt="image" src="https://github.com/user-attachments/assets/997fc49f-7124-4fda-b0d7-0a402931a08b" />
<Timing, Power Analysis of Single-cycle RV32I>


<img width="296" height="141" alt="image" src="https://github.com/user-attachments/assets/4c05c8a7-c41d-4606-8c7b-0bb8eb60b250" />
<Timing, Power Analysis of Multi-cycle RV32I>


## 4. Trouble Shooting
