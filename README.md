# Multi-cycle-RISC-V-32I-APB-Peripheral


## 0. Summary

#### ABSTRACT
- Multi-cycle RISC-V 32I Core
- APB Bus 기반 Peripheral 설계
- C코드 알고리즘(UP, DOWN 게임) 적용

#### 개발 환경 및 ARCHITECTURE
- MCU : HAVARD Architecture 기반 RISC-V 32I
- Interface(BUS) : APB
- Tool : Vivado
- Language : Systemverilog
- FPGA Board : Basys3


## 1. Instruction

### 1.1 RISC-V 32I

### 1.2 Multi Cycle

### 1.3 APB Interface & MMIO



## 2. Hardware Architecture

### 2.1 Overall Structure
<img width="953" height="555" alt="image" src="https://github.com/user-attachments/assets/1c5d55da-386a-45b5-b02e-8f3085ced0be" />

- Multi-cycle CPU Core
  - 명령어의 실행 과정을 Fetch, Decode, Execute, Memory, Write-Back로 분할해 순차적으로 처리하는 프로세서 코어

- APB Master
  - CPU의 Read/Write 요청을 받아 AMBA APB 버스 프로토콜 규격에 맞는 제어 신호를 생성하여 주변 장치들과의 통신

- APB Slave
  - APB Master가 생성한 제어 신호와 주소에 따라 데이터 저장, 외부 출력 등을 수행하고 결과를 Master에게 응답



### 2.2 Core
<img width="913" height="586" alt="image" src="https://github.com/user-attachments/assets/7d1aab43-9888-432e-b5c5-0f0f12a9661c" />

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
<img width="591" height="572" alt="image" src="https://github.com/user-attachments/assets/26326cea-1d5a-4d06-b674-2be011ce302b" />


- APB Master
  - 모든 slave에 Address와 Data를 뿌려주는 broadcasting 방식 적용
  - APB Interface 주요 신호
    : PSEL, PENABLE, PWRITE, PADDR, PWDATA, PRDATA, PREADY, PSLVERR

- APB Slave
  - RAM, GPO, GPIO, FND, UART를 APB Slave로 구성


### 2.4 MMIO
<img width="881" height="446" alt="image" src="https://github.com/user-attachments/assets/c7ec121e-5d82-4270-b434-2ae4dfa3497d" />

  -  Memory Map I/O
    - CPU가 주변 장치에 접근할 때, 별도의 I/O 명령어를 쓰지 않고 일반 메모리 주소(Memory Address) 공간을 할당하여 접근하는 방식
    - UART, FND, GPIO, GPI(사용 x), GPO, BRAM

  - Offset
    : 주변 장치의 Base Address로부터 상대적인 거리(주변 장치 내부 Register 주소)



## 3. Result

### 3.1 FPGA
<img width="723" height="405" alt="image" src="https://github.com/user-attachments/assets/d3421272-af6c-4ab2-9e77-97f5e4521b5c" />

<C 코드(UP, DOWN game) 적용 사진>


#### 3.2 UP, DOWN GAME
- C code(UP, DOWN 게임)
  - UART로 4자리 정답값 설정 후 ‘s’ send
  - Switch로 예측값 설정
  - UART로 ‘i’ send
  - 예측값과 정답값을 비교
  - FND에 ‘PASS’, ‘LOW’, ‘HIGH’ 출력





<동영상>



### 3.2 IMPLEMENTATION
<img width="756" height="353" alt="image" src="https://github.com/user-attachments/assets/a5fc54e7-3e71-4114-85e8-024cfd799c7c" />

<Timing, Power Analysis of Single-cycle RV32I>


<img width="758" height="355" alt="image" src="https://github.com/user-attachments/assets/c3c9eabf-b1ba-4379-baf0-ac255819ad6b" />

<Timing, Power Analysis of Multi-cycle RV32I>
