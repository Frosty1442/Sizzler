# Sizzler Architecture - From the Paper

## What Sizzler Actually Does

Sizzler is **NOT** just generic AFL fuzzing. It's a specialized vulnerability discovery framework for **Programmable Logic Controllers (PLCs)** that combines:
1. **AFL fuzzing** (modified)
2. **Seq-GAN** (Sequential Generative Adversarial Network)
3. **PLC firmware emulation**

## The Problem Being Solved

- PLCs control critical infrastructure (nuclear, energy, manufacturing)
- PLC firmware is proprietary and vendor-locked
- Ladder Diagrams (LD) are the most common PLC programming language
- Standard fuzzing doesn't work well on PLCs
- No generic vulnerability detection exists for PLCs

## Key Innovation

**Seq-GAN learns optimal sequences of mutation operators** from AFL's havoc stage to generate better test cases that discover deeper code paths in PLC ladder logic.

---

## Complete Sizzler Workflow

```
┌─────────────────────────────────────────────────────────┐
│ 1. LADDER DIAGRAM INPUT                                 │
│    (.ld files from "Ladder Diagram Testbed/")          │
└────────────────┬────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│ 2. CONVERSION TO C CODE                                 │
│    Tools: LDmicro or OpenPLC                           │
│    - Converts visual ladder logic → ANSI C             │
│    - Maps I/O to GPIO/I2C interfaces                   │
│    - Includes MCU peripheral libraries                 │
└────────────────┬────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│ 3. AFL INSTRUMENTATION & COMPILATION                    │
│    - Compile with afl-gcc                              │
│    - Binary runs on emulated MCU                       │
└────────────────┬────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│ 4. MCU FIRMWARE EMULATION (QEMU + Avatar2)            │
│    - QEMU: Emulates MCU (ARM, AVR, PIC)                │
│    - Custom GPIO driver: receives sensor inputs        │
│    - Custom I2C driver: board-level communication      │
│    - Modbus/TCP: industrial protocol (via Avatar2)     │
│    - HIL (Hardware-in-the-Loop): simulates real PLC    │
└────────────────┬────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│ 5. AFL FUZZING (Modified Havoc Stage)                  │
│    - Generates test inputs → GPIO ports                │
│    - Records mutation operator sequences that find:    │
│      * New code paths                                  │
│      * Edge coverage                                   │
│      * Crashes                                         │
│    - Uses "effector map" to track effective bytes     │
└────────────────┬────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│ 6. SEQ-GAN TRAINING (Every 10 cycles)                  │
│    Input: Sequences of mutation operators              │
│    - Generator (LSTM): Creates new operator sequences  │
│    - Discriminator (CNN): Real vs Generated sequences  │
│    - Policy Gradient: Updates based on rewards         │
│    Output: Optimized mutation sequences                │
└────────────────┬────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│ 7. ENHANCED FUZZING                                     │
│    - Apply Seq-GAN generated sequences                 │
│    - Target "matebytes" from effector map              │
│    - Generate more effective test cases                │
│    - Discover vulnerabilities faster                   │
└────────────────┬────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│ 8. VULNERABILITY DETECTION                              │
│    - Crashes, infinite loops, race conditions          │
│    - Found CVE-2023-43184 (OpenPLC buffer overflow)    │
│    - Timer integer overflows                           │
│    - Cycle integer overflows                           │
└─────────────────────────────────────────────────────────┘
```

---

## Component Details

### 1. Ladder Diagrams (.ld files)
- **Location**: `/Ladder Diagram Testbed/` (32 files)
- **Format**: Visual programming language for PLCs
- **Content**: Rungs with coils, contacts, timers, counters
- **Vulnerabilities Injected**:
  - Race conditions (RC)
  - Infinite loops (IL)
  - Hidden jumpers (HJ)
  - Object repeat reference (ORR)
  - Hard-coded comparators (CH)
  - Missing jumps/links (MJL)
  - Unused objects (UO)

### 2. AFL Fuzzer (C Component)
- **Location**: `/Fuzzing/` directory
- **Version**: AFL 2.57b (modified)
- **Key Modification**: Enhanced havoc stage
- **What It Does**:
  - Mutates inputs using operators: bit flip, byte flip, arithmetic, etc.
  - Records which operator sequences trigger new paths
  - Stack up to 128 operators per test case
  - Uses coverage-guided feedback

### 3. Seq-GAN (Python Component)
- **Location**: Now in `/sizzler/` (refactored)
- **Files**:
  - `sizzler/models/generator.py` - LSTM-based sequence generator
  - `sizzler/models/discriminator.py` - CNN-based discriminator
  - `sizzler/models/rollout.py` - Monte Carlo rollout for rewards
  - `sizzler/training/loss.py` - Policy gradient loss
  - `sizzler/training/data_iter.py` - Data loading
- **Architecture**:
  - Generator: 2 LSTM layers (128 units each) + Dropout (0.3)
  - Discriminator: 3 CNN layers
  - Input: 100-dimensional Gaussian noise
  - Batch size: 128 (matches AFL's max operator stack)
  - Learning rate: 0.001

### 4. Training Data Format
- **NOT** random integers like I generated!
- **Actually**: Sequences of AFL mutation operators that found new paths
- **Example Sequence**: `[BitFlip, InsertDict, Arithmetic, InterestingValues, ...]`
- **Encoding**: Operators encoded as integers, normalized with Min-Max scaling
- **Length**: Up to 128 operators per sequence

### 5. MCU Emulation Stack
```
┌──────────────────────────────────────┐
│  Ladder Diagram Binary               │
├──────────────────────────────────────┤
│  OpenPLC Runtime / LDmicro Runtime   │
├──────────────────────────────────────┤
│  Custom GPIO Driver (memory-mapped)  │
│  Custom I2C Driver (SDA/SCL lines)   │
├──────────────────────────────────────┤
│  QEMU (Emulates MCU processor)       │
│  - ARM Cortex-M                      │
│  - AVR ATmega                        │
│  - PIC16                             │
├──────────────────────────────────────┤
│  Avatar2 (Modbus/TCP emulation)      │
└──────────────────────────────────────┘
```

### 6. Test MCUs Used in Paper
1. **PIC1616F628** - 8-bit microcontroller
2. **PIC1616F88** - 8-bit microcontroller
3. **Atmel AVR ATmega 2560** - 8-bit AVR
4. **Atmel AVR ATmega 128** - 8-bit AVR
5. **ARM STM32F40X** - 32-bit ARM Cortex-M4

---

## Mutation Operator Sequences

### AFL Havoc Operators (What Seq-GAN Learns)
1. **Bit flip** - Flip random bits
2. **Byte flip** - Flip random bytes
3. **Arithmetic** - Add/subtract from integers
4. **Interesting values** - Replace with known interesting values (0, -1, MAX_INT, etc.)
5. **Dictionary tokens** - Insert known protocol tokens
6. **Block delete** - Remove chunks
7. **Block duplicate** - Duplicate chunks
8. **Block swap** - Swap chunks

### How Seq-GAN Improves This
- AFL randomly stacks operators (up to 128)
- Seq-GAN learns which sequences are most effective
- Example learned sequence:
  ```
  BitFlip → Arithmetic → InsertDict → InterestingValues
  ```
- This is more effective than random stacking

---

## What The Data Actually Represents

### Wrong (What I Did):
```python
# Random integers (ladder logic tokens)
3 9 0 9 9 5 7 3 3 8 ...
```

### Correct (What It Should Be):
```python
# Sequences of mutation operators that found new paths
0 5 2 7 1 3 8 4 ...
# Where: 0=BitFlip, 1=ByteFlip, 2=Arithmetic, etc.
```

### Effector Map
- Tracks which byte positions in input cause different code paths
- Only mutates "matebytes" - bytes that trigger unique paths
- Example:
  ```
  Input:  [0 1 0 0 1 0 1 0]
  Effector: [0 1 0 0 1 1 1 0]  ← positions 1, 4, 5, 6 are matebytes
  ```

---

## Vulnerabilities Detected by Sizzler

### From the Paper (Table III):
- **29 out of 30** programs crashed
- Detected vulnerabilities:
  1. **Timer integer overflow** - Large value causes infinite loop
  2. **Cycle integer overflow** - Counter wraps to 0
  3. **CVE-2023-43184** - OpenPLC buffer overflow via Modbus
  4. **CVE-2018-20818** - Buffer overwrite in modbus.cpp

### Coverage Achieved:
- **Function coverage**: 88.4% average
- **Basic block coverage**: 71.29% average
- **Edge coverage**: 61.4% average

---

## How To Actually Reproduce Sizzler

### Step 1: Get Ladder Diagrams
```bash
cd "Ladder Diagram Testbed/"
ls *.ld  # 32 ladder diagram files
```

### Step 2: Convert LD → C Code
```bash
# Using LDmicro (need to install)
ldmicro file.ld → compile to hex → extract C code

# OR using OpenPLC
# Upload LD to OpenPLC editor → compile → get C code
```

### Step 3: Instrument with AFL
```bash
Fuzzing/afl-gcc -o plc_binary converted_ld.c -lruntime
```

### Step 4: Set up QEMU Emulation
```bash
# Need to implement custom GPIO/I2C drivers for QEMU
# This is NOT standard QEMU - they modified it
# Files would be in Fuzzing/ with custom memory mappings
```

### Step 5: Run AFL with Seq-GAN
```bash
# First cycle: AFL collects operator sequences
Fuzzing/afl-fuzz -i seeds -o output -m none -- ./plc_binary

# After 10 cycles: Train Seq-GAN
python sizzler/main.py --data_path ./operator_sequences

# Use generated sequences for next fuzzing cycle
```

---

## Current Repository State

### What We Have ✅:
1. ✅ AFL fuzzer (compiled, tested)
2. ✅ Seq-GAN Python code (refactored into sizzler/)
3. ✅ 32 ladder diagram files (.ld)
4. ✅ Basic package structure

### What's Missing ❌:
1. ❌ LDmicro/OpenPLC conversion pipeline
2. ❌ Custom QEMU GPIO/I2C drivers
3. ❌ Avatar2 integration for Modbus
4. ❌ Proper training data (operator sequences, not random ints)
5. ❌ Integration between AFL and Seq-GAN
6. ❌ MCU firmware runtime libraries

---

## Key Differences From Generic Fuzzing

| Aspect | Generic AFL | Sizzler |
|--------|-------------|---------|
| **Target** | Any binary | PLC ladder logic on MCU |
| **Input** | Files/stdin | GPIO ports (sensor signals) |
| **Emulation** | None/QEMU binary | QEMU + GPIO/I2C/Modbus |
| **Mutation** | Random stacking | Seq-GAN learned sequences |
| **Data** | Any format | Industrial control signals |
| **Feedback** | Code coverage | Coverage + PLC-specific metrics |

---

## Next Steps to Properly Test Sizzler

1. **Install LDmicro** - To convert .ld files to C
2. **Examine one .ld file** - Understand structure
3. **Convert one LD to C** - Test the pipeline
4. **Identify GPIO/I2C code** - Find custom QEMU modifications
5. **Generate REAL training data** - AFL operator sequences
6. **Integrate AFL ↔ Seq-GAN** - Complete the feedback loop
7. **Run full pipeline** - LD → C → AFL → Seq-GAN → Enhanced fuzzing

---

## Paper Citation

**Title**: "Sizzler: Sequential fuzzing in ladder diagrams for vulnerability detection and discovery in Programmable Logic Controllers"

**Authors**: Kai Feng, Marco M. Cook, Angelos K. Marnerides

**Published**: IEEE Transactions on Information Forensics and Security, 2024

**DOI**: 10.1109/TIFS.2023.3340615

**CVE Found**: CVE-2023-43184 (OpenPLC buffer overflow)

---

## Summary

Sizzler is NOT about fuzzing random C programs. It's a sophisticated system that:
1. Takes industrial PLC ladder diagrams
2. Converts them to executable binaries on emulated MCU firmware
3. Fuzzes them with AFL while recording effective mutation sequences
4. Trains a Seq-GAN to learn optimal mutation patterns
5. Uses those patterns to generate better test cases
6. Discovers real vulnerabilities in industrial control systems

The refactored Python code (sizzler/) is ONLY the Seq-GAN component. The full system requires the AFL fuzzer, MCU emulation, and ladder diagram conversion pipeline working together.
