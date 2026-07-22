# 🚀 Multi-cycle RISC-V 32I Core & APB Peripheral Project

> **Basys3 FPGA 기반 Multi-cycle RISC-V (RV32I) 프로세서 및 APB 버스 기반 Peripherals 설계 프로젝트**

---

## 📌 0. Summary

### 🎯 Overview
* **CPU Core:** Harvard Architecture 기반 **Multi-cycle RISC-V 32I Processor**
* **Bus Protocol:** AMBA **APB (Advanced Peripheral Bus)** Protocol
* **Peripherals:** RAM (BRAM), UART, FND (7-Segment), GPIO, GPO
* **Application:** C 언어로 작성된 **UP & DOWN 게임** 하드웨어 포팅 및 제어

### 🛠️ Tech Stack & Environment
* **Architecture:** RISC-V RV32I Base Integer Instruction Set
* **Language:** SystemVerilog, C Language
* **EDA Tool:** Xilinx Vivado
* **Target Board:** Basys3 (Artix-7 FPGA)

---

## 📚 1. Introduction & Background

### 1.1 RISC-V & Harvard Architecture
* **RISC-V (ISA):** 2010년 UC 버클리에서 개방한 오픈소스 ISA로, 모듈형 설계 및 단순한 명령어 구조가 특징
* **Harvard Architecture:**
  * **Instruction Memory**와 **Data Memory**의 **버스 및 메모리 영역이 물리적으로 분리**된 구조
  * 명령어 Fetch와 데이터 Read/Write가 동시에 수행 가능하여 Von Neumann 구조 대비 **병목 현상이 적고 동작 속도가 빠름**

#### RISC-V 32I Instruction Formats (6가지)
| Format | Description | Target Instructions |
| :--- | :--- | :--- |
| **R-Type** | 레지스터 간 산술/논리 연산 | `ADD`, `SUB`, `SLL`, `SLT`, `XOR`, `SRL`, `OR`, `AND` 등 |
| **I-Type** | Immediate 연산, Load, JALR | `ADDI`, `SLTI`, `ANDI`, `LW`, `LH`, `LB`, `JALR` 등 |
| **S-Type** | Data Memory 저장 (Store) | `SW`, `SH`, `SB` |
| **B-Type** | 조건 분기 (Branch) | `BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU` |
| **U-Type** | 상위 20비트 Immediate 설정 | `LUI`, `AUIPC` |
| **J-Type** | 무조건 점프 (Jump) | `JAL` |

---

### 1.2 Multi-Cycle CPU Architecture
* **Single-Cycle의 한계:** 가장 오랫동안 실행되는 명령어(e.g., `LW`)의 Critical Path 시간에 맞춰 클럭 주기를 크게 설정해야 하므로 최대 동작 주파수가 낮아짐
* **Multi-Cycle의 장점:** 명령어를 실행 단계별(최대 5 Stages)로 분할하여 **클럭 주기를 단축(최대 동작 주파수 향상)**시킴

#### 5-Stage Execution Flow
1. **IF (Instruction Fetch):** 메모리에서 명령어를 가져옴
2. **ID (Instruction Decode & Register Read):** 명령어 해석 및 레지스터 읽기
3. **EX (Execution / Address Calculation):** ALU 연산 및 메모리 주소 계산
4. **MEM (Memory Access):** Data Memory에 읽기/쓰기 수행 (`LW`, `SW`)
5. **WB (Write Back):** 최종 연산 결과를 레지스터에 기록

---

### 1.3 APB Bus Interface & MMIO

#### AMBA APB (Advanced Peripheral Bus)
* 저속/저전력 주변장치 제어에 최적화된 단순 구조의 버스 프로토콜
* **Broadcasting & Selective Enable:** 마스터가 Address/Data를 모든 슬레이브 라인에 전송하면, 지정된 슬레이브만 `PSELx` 신호를 활성화하여 응답

#### 주요 APB 신호선
* `PCLK`, `PRESETn` : 시스템 클럭 및 Active-Low 리셋
* `PADDR` : Peripheral 액세스 주소 버스
* `PWRITE` : Read(`0`) / Write(`1`) 제어 신호
* `PSELx` : 특정 Peripheral 선택 (Chip Select)
* `PENABLE` : APB Access Phase 제어 신호
* `PWDATA` / `PRDATA` : Write 데이터 버스 / Read 데이터 버스
* `PREADY` : 슬레이브 응답 준비 완료 신호

#### Memory-Mapped I/O (MMIO) & Offset
* CPU가 별도의 I/O 전용 명령어 없이 **일반 메모리 주소 공간(Address Space)**을 사용하여 주변 장치에 접근
* **Offset:** Peripheral의 Base Address를 기준으로 내부 레지스터에 접근하기 위한 상대 주소

---

## 🧩 2. Hardware Architecture & System Design

### 2.1 Overall System Architecture
<p align="center">
  <img src="https://github.com/user-attachments/assets/1c5d55da-386a-45b5-b02e-8f3085ced0be" width="80%" alt="Overall Architecture">
</p>

* **Multi-cycle CPU Core:** 5단계 상태 머신(FSM)을 통해 명령어를 분할 처리
* **APB Master:** CPU의 메모리 요청을 APB 버스 프로토콜 타임에 맞춰 슬레이브 제어 신호로 변환
* **APB Slaves:** 메모리 맵(MMIO) 영역에 매핑되어 각 I/O 동작 수행

---

### 2.2 Datapath & Control Unit
<p align="center">
  <img src="https://github.com/user-attachments/assets/7d1aab43-9888-432e-b5c5-0f0f12a9661c" width="80%" alt="Core Architecture">
</p>

* Multi-cycle 구조를 채택함으로써 단일 사이클 대비 **Critical Path를 대폭 줄여 동작 주파수(Max Frequency)를 대폭 향상**시킴

---

### 2.3 APB Master & Interconnect System
<p align="center">
  <img src="https://github.com/user-attachments/assets/26326cea-1d5a-4d06-b674-2be011ce302b" width="60%" alt="APB Bus Connection">
</p>

* **Broadcasting 구조:** Address 및 Data 버스는 모든 Slave 라인에 공통 연결
* **Slave MUXing:** 주소 디코더를 거쳐 `PSELx` 신호를 슬레이브별 개별 전달 및 `PRDATA` 선택

---

### 2.4 Memory-Mapped I/O (MMIO) Map
<p align="center">
  <img src="https://github.com/user-attachments/assets/c7ec121e-5d82-4270-b434-2ae4dfa3497d" width="80%" alt="MMIO Memory Map">
</p>

#### Address Allocation Table
| Target Peripheral | Base Address Range | Description |
| :--- | :--- | :--- |
| **BRAM (RAM)** | Memory Map 내 할당 | 메인 데이터 메모리 영역 |
| **UART** | Memory Map 내 할당 | PC-FPGA 간 시리얼 통신 |
| **FND Controller** | Memory Map 내 할당 | 7-Segment 상태 표시 |
| **GPIO / GPO** | Memory Map 내 할당 | 스위치 입력 및 LED 제어 |

---

## 📊 3. Implementation Results & Analysis

### 3.1 Hardware Demonstration (Basys3 FPGA)
<p align="center">
  <img src="https://github.com/user-attachments/assets/d3421272-af6c-4ab2-9e77-97f5e4521b5c" width="70%" alt="FPGA Board Demo">
</p>

* **UP/DOWN Game Flow (Embedded C Application):**
  1. PC Terminal (UART)로 4자리 정답값 설정 후 `'s'` 전송
  2. Basys3 온보드 Switch를 사용해 예측 값 입력
  3. UART로 `'i'` 입력 전송하여 비교 수행
  4. 비교 결과에 따라 FND 7-Segment에 **`PASS`**, **`LOW`**, **`HIGH`** 실시간 출력

---

### 3.2 Timing & Power Analysis Comparison

| Single-cycle RV32I Result | Multi-cycle RV32I Result (Proposed) |
| :---: | :---: |
| <img src="https://github.com/user-attachments/assets/a5fc54e7-3e71-4114-85e8-024cfd799c7c" width="100%"> | <img src="https://github.com/user-attachments/assets/c3c9eabf-b1ba-4379-baf0-ac255819ad6b" width="100%"> |

> **💡 Synthesis & Implementation Result Analysis**
> * **Critical Path 개선:** Single-cycle 대비 명령어 실행 경로가 Stage별로 분할되어 **Data Path Latency(WNS/Setup Slack)가 대폭 개선**됨.
> * **동작 주파수 향상:** 클럭 주기를 단축할 수 있어 더 높은 주파수 대역폭 확보가 가능해짐
