# Multi-cycle_RISC-V_32I_APB_Peripheral


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

### 1.1 RISC-V
  - RISC-V
    - 2010년 미국 UC 버클리 대학에서 시작된 오픈소스 개방형 명령어 집합 아키텍처(ISA, Instruction Set Architecture)
      - ISA : CPU가 알아듣는 언어 체계
    - 특징
      - Open Source : 라이센스 비용 없이 자유롭게 CPU 코어를 설계, 판매 가능
      - 모듈형 설계 : 기본 틀에 필요한 모듈 추가 가능
      - CPU 구조 단순 : 핵심 명령어가 많지 않음
    - RISC-V 구성 요소
      - Instruction Memory : Instruction을 저장하는 memory(rom), PC가 가리키는 주소의 명령어를 읽음
      - Register file : ALU 연산을 위한 임시 저장 공간(CPU 내부 존재)
      - Data Memory : CPU 외부에 있는 저장 공간(RAM), Data를 store 하거나 load 하기 위한 공간
      - ALU : 실제 연산을 수행하는 공간(+, -, /, >>, <<, <<<, &, |, ^, <, > 등)
      - Control unit : 명령어를 해석하여 CPU의 동작을 제어
      - Program Counter : 다음에 실행할 명령어의 주소를 가리키는 32비트 레지스터
     
        
  - Havard Architecture
    - 명령어(Instruction)가 저장되는 메모리"와 "데이터(Data)가 저장되는 메모리"가 물리적으로 완전히 분리된 컴퓨터 구조
    - 특징
      - 독립된 메모리 영역 : Instruction Memory(ROM)과 Data Memory(RAM) 분리
      - 독립된 버스 (Bus): CPU가 명령어를 가져오는 경로(Instruction Bus)와 데이터를 읽고 쓰는 경로(Data Bus)가 분리
      - Instruction Fetch(CPU가 명령어 Fetch)와 데이터 Read/Write 동시에 가능
     
    - Von Neumann(폰 노이만) Architecture
      - Von Neumann의 메모리 구조 : 명령어와 데이터가 단일 메모리에 혼재
      - Von Neumann의 버스 : 하나의 버스를 공유
      - Von Neumann 동작 속도 : 상대적으로느림(Havard 구조는 명령어 Fetch와 데이터 Access 동시 수행 가능하므로 동작 속도가 폰 노이만 구조에 비해 빠름)
      - 병복현상 발생 가능 - 하나의 버스로 명령어와 데이터를 번갈아 가져와야 하기 때문에 버스에서 병목 현상 발생 가능


    - RISC-V 32I
      <img width="720" height="295" alt="image" src="https://github.com/user-attachments/assets/66d2dd01-eb8d-43f7-9fea-04adff1b0fa4" />
      
      - 정의 : 32비트 정수(Integer) 기본 명령어 SET
      - 6가지 Instruction Format 존재
        - R-type : 레지스터 간 산술/논리 연산
          - ex) ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND
        - I-type : 상수(Immediate) 연산, Load, JALR
          - ex) ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI / LB, LH, LW, LBU, LHU / JALR
        - S-type : Data Mem에 저장 (Store)
          - ex) SB, SH, SW
        - B-Type : 조건 분기 (Branch)
          - ex) BEQ, BNE, BLT, BGE, BLTU, BGEU
        - U-Type : 상위 20비트 상수 설정
          - ex) LUI, AUIPC
        - J-Type : 무조건 점프 (Jump)
          - ex) JAL
        
### 1.2 Multi Cycle
  - Multi-Cycle CPU : 하나의 명령어(Instruction)를 실행하는 데 여러 클럭 사이클(Clock Cycles)에 걸쳐 나누어 처리하는 CPU 설계 구조
  - Single-Cycle CPU : 하나의 명령어(Instruction)를 실행할 때, 한 Clock Cycle 안에 처리하는 CPU 설계 구조

  - Multi-Cycle CPU의 장점(than Single-Cycle CPU)

    <img width="633" height="248" alt="image" src="https://github.com/user-attachments/assets/976b80d8-8097-4277-a163-72e3318e5e77" />

    - 오래 걸리는 명령어(LW)를 기준으로 클럭 주기를 크게 설정해야 함 -> 느려짐
    - 명령어를 최대 5단계로 나눠 클럭 주기를 낮출 수 있음
      
  - Instruction 실행 5가지 단계
    - IF (Instruction Fetch): 메모리에서 명령어를 가져옴
    - ID (Instruction Decode & Register Read): 명령어를 해석하고 레지스터 값을 읽음
    - EX (Execution / Address Calculation): ALU를 통해 연산하거나 메모리 주소를 계산함
    - MEM (Memory Access): 메모리에 데이터를 쓰거나(SW) 읽음(LW)
    - WB (Write Back): 최종 결과를 레지스터에 기록함

   
      
### 1.3 APB Interface & MMIO
  - APB(Advanced Peripheral Bus)
    
    <img width="560" height="340" alt="image" src="https://github.com/user-attachments/assets/ea29257f-32df-4bf2-b932-d6f08a070f46" />

      - 저속 & 저전력 최적화
      - 단순한 구조 (No Pipeline) - 한 번에 하나의 데이터를 주고 받음
      - Signal
        - PCLK / PRESETn: APB 버스의 클럭 신호와 리셋(Active Low) 신호
        - PADDR: 마스터가 접근하려는 Peripheral의 내부 주소(Address) 버스
        - PWRITE: Read/Write를 결정(1이면 Write, 0이면 Read)
        - PSEL (Peripheral Select): 마스터가 특정 슬레이브 장치를 선택하는 Chip Select 신호
        - PENABLE: 데이터 전송의 실제 타이밍을 제어하는 신호
        - PWDATA / PRDATA: 쓰기 데이터(Write Data) 버스 / 읽기 데이터(Read Data) 버스
        - PREADY : 슬레이브가 데이터 준비 완료됐다고 마스터에게 알려주는 신호입니다. (준비가 안 되었다면 마스터는 대기)

  - Memory Map I/O
      - CPU가 주변 장치에 접근할 때, 별도의 I/O 명령어를 쓰지 않고 일반 메모리 주소(Memory Address) 공간을 할당하여 접근하는 방식
    
  - Offset
      - 주변 장치의 Base Address로부터 상대적인 거리(주변 장치 내부 Register 주소)

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

<전체 MMIO>

- UART, FND, GPIO, GPI(사용 x), GPO, BRAM




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
<img width="450" height="210" alt="image" src="https://github.com/user-attachments/assets/a5fc54e7-3e71-4114-85e8-024cfd799c7c" />

<Timing, Power Analysis of Single-cycle RV32I>


<img width="450" height="210" alt="image" src="https://github.com/user-attachments/assets/c3c9eabf-b1ba-4379-baf0-ac255819ad6b" />

<Timing, Power Analysis of Multi-cycle RV32I>
