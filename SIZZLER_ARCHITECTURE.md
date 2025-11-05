# Sizzler Architecture - Complete Analysis from IEEE TIFS 2024 Paper

## Paper Reference
**Title:** Sizzler: Sequential fuzzing in ladder diagrams for vulnerability detection and discovery in Programmable Logic Controllers
**Authors:** Kai Feng, Marco M. Cook, Angelos K. Marnerides
**Published:** IEEE Transactions on Information Forensics and Security, 2024
**DOI:** 10.1109/TIFS.2023.3340615

## What Sizzler Actually Does

Sizzler is **NOT** just generic AFL fuzzing. It's a specialized vulnerability discovery framework for **Programmable Logic Controllers (PLCs)** that combines:
1. **Modified AFL fuzzing** with enhanced havoc strategy
2. **SeqGAN** (Sequential Generative Adversarial Network) with policy gradient
3. **PLC firmware emulation** via QEMU + Avatar2
4. **Effector map** tracking for matebytes identification

## The Problem Being Solved

- PLCs control critical infrastructure (nuclear, energy, manufacturing, utilities)
- PLC firmware is proprietary and vendor-locked (no generic solutions)
- Ladder Diagrams (LD) are the most common PLC programming language
- Standard fuzzing doesn't work well on PLCs (lack of feedback mechanisms)
- No generic vulnerability detection exists for PLCs
- PLC compilers lack fundamental security checks during ladder diagram compilation
- Vendor-specific instruction sets make generic analysis impossible

## Key Innovation

**SeqGAN learns optimal sequences of mutation operators** from AFL's havoc stage using:
- **LSTM Generator** (2 layers, 128 units each, 0.001 learning rate)
- **CNN Discriminator** (3 layers)
- **Policy Gradient** updates based on rewards (Equation 2 in paper)
- **Matebytes** targeting from effector map (bytes causing different code paths)
- **Every 10 cycles** retraining with new operator sequences

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

## CVEs Discovered by Sizzler

### CVE-2023-43184 - OpenPLC Buffer Overflow ⭐
**Severity:** HIGH  
**CWE:** CWE-120 (Buffer Overflow)  
**CVE Link:** https://packetstormsecurity.com/files/174582/OpenPLC-Webserver-3-Denial-Of-Service-Buffer-Overflow.html

**Description:**  
Buffer overflow vulnerability in OpenPLC runtime that enables attackers to:
- Inject malicious code via slave device attributes
- Escalate to root privileges
- Cause server crash when PLC connects with equipment via Modbus protocol

**Location:** Modbus/TCP connection handling in OpenPLC runtime

**How Sizzler Found It:**  
- Fuzzed Modbus slave device attribute strings
- Generated abnormally large inputs for device names/attributes
- Triggered overflow when PLC runtime processed Modbus connection
- Binary crashed reproducibly with specific input patterns

### CVE-2018-20818 - OpenPLC Memory Corruption
**Severity:** MEDIUM  
**CWE:** CWE-787 (Out-of-bounds Write)

**Description:**  
Buffer named `in memory` declared in `glue_generator.cpp` file is also invoked in `modbus.cpp` and is susceptible to being overwritten beyond its 1024th position, thereby interrupting the loop and causing the runtime to halt.

**Location:**  
- `glue_generator.cpp` - Buffer declaration
- `modbus.cpp` - Buffer usage

### Additional Vulnerabilities Found

#### Timer Integer Overflow
**Type:** Integer Overflow → Infinite Loop  
**Description:** Sizzler identified an integer overflow in the Ladder Diagram timer function. When abnormally large value assigned to input parameter, the program enters an infinite loop within OpenPLC environment.

**Example:**  
```c
// Timer with max value causes overflow
timer_value = 0xFFFFFFFF;  // Sizzler sets this
// Causes infinite loop in timer counting logic
```

#### Cycle Integer Overflow  
**Type:** Integer Overflow → Logic Bypass  
**Description:** The `Ui_Ccycle` variable controls three output coils based on cycle count ranges. When Sizzler increments `Ui_Ccycle` to maximum value, it wraps around to 0, causing program to execute indefinitely with incorrect coil states.

**Example:**  
```c
// Cycle counter wraps around
if (Ui_Ccycle < 100) output1 = ON;
else if (Ui_Ccycle < 200) output2 = ON;
else output3 = ON;
// When Ui_Ccycle = MAX → wraps to 0, output1 = ON forever
```

---

## Vulnerability Types Tested

### 1. Race Condition Competition (RC)
**Example:** Two processes concurrently request the same resource. Output value of `y_new` changes from 0 to 1 within two cycles even though inputs are fixed.

**Ladder Logic Pattern:**
```
Rung 1: X_input → [SET Y_output]
Rung 2: X_input → [RESET Y_output]
```

### 2. Infinite Loop (IL)
**Impact:** Consumes excessive CPU resources, causes PLC crash  
**How Created:** LD contains unconditional jump back to same rung or cycle without termination condition

### 3. Hard-coded Logical Comparator (CH)
**Risk:** Embedded in application, accessible by attackers  
**Example:** `if (var == 0x12345678)` - attacker reverse engineers and modifies var

### 4. Missing Jumps and Links (MJL)
**Attack Vector:** Attacker identifies unused memory addresses and inserts malicious code in empty jump target spaces

### 5. Hidden Jumpers (HJ)
**Problem:** Jump mechanism skips elements unintentionally. Jumper coded to bypass single element may skip entire branch or multiple elements.

### 6. Object Repeat Reference (ORR)
**Issue:** One output controlled by different inputs. Output coil duplicated in LD, gets de-energized depending on which rung executes, resulting in undesired output.

### 7. Unused Objects (UO)
**Vulnerability:** Variables remain unused in large PLC programs, not detected by compiler. Open entry points for malicious code injection.

### 8. Missing Certain Coils/Outputs
**Impact:** Rung missing output coil (OTE, latches, sets, unlatches) leads to dependency issues affecting other tags.

---

## Implementation Requirements (What's Missing)

### ⚠️ CRITICAL: Current Repository Status

**What EXISTS:**
- ✅ Seq-GAN Python models (Generator, Discriminator, Target LSTM, Rollout)
- ✅ Training infrastructure (data iterators, policy gradient loss)
- ✅ AFL 2.57b fuzzer source code
- ✅ 32 Ladder Diagram test files (.ld format)
- ✅ Python packaging (pyproject.toml, setup.py)
- ✅ Docker support

**What's MISSING (Must Implement):**
- ❌ LDmicro or OpenPLC installation/integration
- ❌ LD → C conversion pipeline
- ❌ QEMU + Avatar2 emulation setup
- ❌ Custom GPIO driver for QEMU
- ❌ Custom I2C driver for QEMU
- ❌ Modbus/TCP via Avatar2
- ❌ AFL modification to record mutation operator sequences
- ❌ Integration between AFL and Seq-GAN
- ❌ Effector map implementation
- ❌ Matebyte tracking
- ❌ Training data generation from AFL

### Required Dependencies

**System Level:**
```bash
# LDmicro - Ladder diagram compiler
# Download from: https://github.com/LDmicro/LDmicro
# OR use package manager if available

# OpenPLC - Open-source PLC runtime
# Clone from: https://github.com/thiagoralves/OpenPLC_v3
# Follow build instructions

# QEMU - MCU emulator
apt-get install qemu-system-arm qemu-system-avr

# Avatar2 - Dynamic analysis framework
pip install avatar2

# Additional libraries
apt-get install libglib2.0-dev libpixman-1-dev
```

**Python Packages (add to requirements.txt):**
```
avatar2>=1.4.0
keystone-engine>=0.9.2
capstone>=4.0.2
unicorn>=1.0.2
```

### Implementation Steps

#### Step 1: Setup LDmicro/OpenPLC
```bash
# Option A: LDmicro
git clone https://github.com/LDmicro/LDmicro
cd LDmicro && mkdir build && cd build
cmake .. && make
# Creates ldmicro binary that can compile .ld → .c

# Option B: OpenPLC
git clone https://github.com/thiagoralves/OpenPLC_v3.git
cd OpenPLC_v3 && ./install.sh linux
# Creates glue_generator that converts IEC 61131-3 → C
```

#### Step 2: Convert Ladder Diagrams
```bash
# For each .ld file in "Ladder Diagram Testbed/"
for ld_file in "Ladder Diagram Testbed"/*.ld; do
    # LDmicro method
    ldmicro -c "$ld_file" -o "$(basename $ld_file .ld).c"
    
    # OR OpenPLC method (requires .st structured text)
    # Need to convert .ld → .st first
done
```

#### Step 3: Instrument with AFL
```bash
# Build AFL
cd Fuzzing && make

# Compile each converted C file
export AFL_USE_ASAN=1  # Enable AddressSanitizer
./afl-gcc -o test_binary test_program.c -ITARGET_MCU_HEADERS
```

#### Step 4: Setup QEMU Emulation
```python
# Python script using Avatar2
from avatar2 import *

# Create Avatar instance
avatar = Avatar(arch=ARM_CORTEX_M3)

# Add QEMU target
qemu = avatar.add_target(QemuTarget, 
                         executable="test_binary",
                         cpu_model="cortex-m3")

# Map GPIO memory region (example for STM32)
GPIO_BASE = 0x40020000
GPIO_SIZE = 0x2C00
avatar.add_memory_range(GPIO_BASE, GPIO_SIZE, 
                        name='gpio', permissions='rw')

# Map I2C memory region
I2C_BASE = 0x40005400
I2C_SIZE = 0x400
avatar.add_memory_range(I2C_BASE, I2C_SIZE,
                        name='i2c', permissions='rw')

# Start emulation
avatar.init_targets()
qemu.cont()
```

#### Step 5: Modify AFL to Record Sequences
```c
// In afl-fuzz.c, add to havoc_stage function:

FILE *sequence_log = fopen("operator_sequences.txt", "a");

// When new path found:
if (fault == FAULT_NONE && new_bits) {
    // Log the sequence of operators that led here
    for (int i = 0; i < havoc_stack_len; i++) {
        fprintf(sequence_log, "%d ", havoc_stack[i]);
    }
    fprintf(sequence_log, "\n");
    fflush(sequence_log);
}

fclose(sequence_log);
```

#### Step 6: Train Seq-GAN
```python
# Use existing sizzler package
from sizzler.models.generator import Generator
from sizzler.models.discriminator import Discriminator
from sizzler.training.data_iter import GenDataIter
from sizzler.training.loss import PGLoss

# Load AFL operator sequences
with open('operator_sequences.txt') as f:
    sequences = [[int(x) for x in line.split()] for line in f]

# Train model (see sizzler/main.py for complete training loop)
# ... training code ...
```

#### Step 7: Feed Generated Sequences Back to AFL
```c
// In AFL, read Seq-GAN generated sequences
FILE *seqgan_output = fopen("generated_sequences.txt", "r");

// Use these sequences instead of random havoc
while (fscanf(seqgan_output, "%d", &operator_id) == 1) {
    apply_mutation_operator(operator_id, buffer, len);
}
```

---

## Evaluation Results from Paper

### PLC Binary Testing
- **30 vulnerable PLC binaries** tested across 5 MCUs
- **Average function coverage:** 88.4%
- **Average basic block coverage:** 71.29%  
- **Average edge coverage:** 61.4%
- **Crashes found:** 29 out of 30 programs
- **Typical execution time:** 40-67 minutes per binary (10 cycles)

### Comparison with Other Fuzzers (LAVA-M Dataset)
- **Sizzler:** 44 bugs (base64), 46 (md5sum), 18 (uniq), 981 (who)
- **Sizzler+Angora:** 48 bugs (base64), 57 (md5sum), 28 (uniq), 1711 (who) ⭐ BEST
- **NEUZZ:** 46, 55, 27, 1562
- **Angora:** 48, 57, 26, 1531
- **AFL++:** 3, 1, 19, 772
- **AFL:** 0, 0, 2, 1

### Magma Dataset
- **Sizzler:** 39 bugs average
- **MOPT:** 37 bugs  
- **AFL++:** 19 bugs
- **Angora:** 17 bugs
- **NEUZZ:** 15 bugs

### Performance
- **Execution speed:** 0-3500 exec/sec (Sizzler) vs 0-600 exec/sec (others)
- **Reason:** Emulation on native architecture, focus on havoc stage

---

## Key Takeaways

1. **Sizzler is NOT just Python code** - it's a complete fuzzing pipeline with AFL + Seq-GAN + QEMU emulation
2. **Training data is NOT random integers** - it's sequences of AFL mutation operators that found new paths
3. **Can't test without full pipeline** - need LD→C→Binary→QEMU→AFL→Seq-GAN loop
4. **Two CVEs discovered** - CVE-2023-43184 (buffer overflow) and CVE-2018-20818 (memory corruption)
5. **Works beyond PLCs** - achieves high performance on LAVA-M and Magma datasets
6. **Hybrid approach wins** - Sizzler+Angora combination achieved best results

---

## Citations & References

**Main Paper:**
```bibtex
@article{feng2024sizzler,
  title={Sizzler: Sequential fuzzing in ladder diagrams for vulnerability detection and discovery in Programmable Logic Controllers},
  author={Feng, Kai and Cook, Marco M and Marnerides, Angelos K},
  journal={IEEE Transactions on Information Forensics and Security},
  volume={19},
  pages={1660--1671},
  year={2024},
  doi={10.1109/TIFS.2023.3340615}
}
```

**Key Technologies:**
- AFL: https://lcamtuf.coredump.cx/afl/
- SeqGAN: Yu et al. (2017), AAAI Conference
- QEMU: https://www.qemu.org/
- Avatar2: Muench et al. (2018)
- OpenPLC: https://openplcproject.com
- LDmicro: https://cq.cx/ladder.pl

**Related CVEs:**
- CVE-2023-43184: https://packetstormsecurity.com/files/174582/
- CVE-2018-20818: OpenPLC memory corruption

