# AFL + Seq-GAN Integration Analysis

## Current Integration Status

The AFL fuzzer in `/Fuzzing/afl-fuzz.c` **already has Seq-GAN integration code**!

### Key Integration Points

#### 1. Seq-GAN Output Loading (Line 6107-6121)
```c
int a[6400][154];  // 6400 samples, 154 operators per sequence
FILE* fop = fopen("/home/gla/data/gene.data","r");
for(x=0;x<6400;x++) {
  for(y=0;y<154;y++) {
    fscanf(fop,"%d",&a[x][y]);
  }
}
```

**Dimensions:**
- `6400`: Number of generated sequences (matches `--n_samples` in main.py)
- `154`: Max operators per sequence (related to AFL's HAVOC_STACK_POW2 = 7, max stack = 128)

#### 2. Operator Application Loop (Line 6572-6580)
```c
for (i = 0; i< 6400; i++) {
  u32 use_stacking = 1 << (1 + UR(HAVOC_STACK_POW2));
  stage_cur_val = use_stacking;
  
  for (j = 0; j<154; j++) {
    switch (a[i][j]) {
      case 0: /* Bit flip */
      case 1: /* Interesting byte */
      // ... etc
    }
  }
}
```

## AFL Mutation Operator Encoding

Based on `afl-fuzz.c` lines 6580-onwards, here's the operator mapping:

| ID | Operator Name | Description |
|----|---------------|-------------|
| 0  | Bit flip | Flip a single random bit |
| 1  | Interesting byte | Set byte to interesting value |
| 2  | Interesting word | Set 16-bit word to interesting value |
| 3  | Interesting dword | Set 32-bit dword to interesting value |
| 4  | Random subtract byte | Subtract random value from byte |
| 5  | Random add byte | Add random value to byte |
| 6  | Random subtract word | Subtract from 16-bit word |
| 7  | Random add word | Add to 16-bit word |
| 8  | Random subtract dword | Subtract from 32-bit dword |
| 9  | Random add dword | Add to 32-bit dword |
| 10 | Random byte | Set random byte to random value |
| 11 | Delete bytes | Remove chunk of bytes |
| 12 | Clone bytes | Duplicate chunk of bytes |
| 13 | Overwrite bytes | Overwrite with another chunk |
| 14 | Dictionary insert | Insert token from dictionary (extras) |
| 15 | Auto dictionary insert | Insert auto-detected token |

## Required Files

### Input: `/home/gla/data/gene.data`
**Format:** Text file with space-separated integers
```
0 5 2 7 1 3 10 8 ...  (154 values)
1 2 3 4 5 6 7 8 ...   (154 values)
...
(6400 lines total)
```

**How to Generate:**
1. Train Seq-GAN model using `sizzler/main.py`
2. After training, generator produces sequences
3. Save generated sequences to `gene.data`

### Output Logging
AFL logs applied operators to file pointer `fp` (needs to be defined)

## Missing Pieces

1. ❌ **gene.data file** - Need to generate from trained Seq-GAN
2. ❌ **File path configuration** - Hardcoded `/home/gla/data/gene.data`
3. ❌ **Training data collection** - Need to record which operator sequences found new paths
4. ❌ **Feedback loop** - Need to retrain Seq-GAN every 10 cycles with new data

## How Sizzler Workflow Should Work

```
1. Initial AFL Fuzzing (Random Havoc)
   └─> Records operator sequences that found new paths
   └─> Saves to training data file

2. Train Seq-GAN (Every 10 cycles)
   └─> Reads training data (successful operator sequences)
   └─> Trains Generator + Discriminator
   └─> Generates 6400 new sequences
   └─> Saves to gene.data

3. Enhanced AFL Fuzzing
   └─> Reads gene.data
   └─> Uses Seq-GAN sequences instead of random
   └─> Finds vulnerabilities faster!
```

## Next Steps to Complete Integration

### Step 1: Fix Hardcoded Path
```c
// Change line 6109 from:
FILE* fop = fopen("/home/gla/data/gene.data","r");

// To:
const char* seqgan_data = getenv("SIZZLER_SEQGAN_DATA");
if (!seqgan_data) seqgan_data = "./data/gene.data";
FILE* fop = fopen(seqgan_data, "r");
```

### Step 2: Add Operator Sequence Logging
```c
// At havoc_stage, add file for logging successful sequences
FILE* training_log = fopen("./data/training_sequences.txt", "a");

// When new path found, log the operators used:
if (fault == FAULT_NONE && new_bits) {
  for (int k = 0; k < operators_used; k++) {
    fprintf(training_log, "%d ", operator_history[k]);
  }
  fprintf(training_log, "\n");
  fflush(training_log);
}
```

### Step 3: Generate Initial gene.data
```python
# Use sizzler package
python3 -m sizzler.main --data_path ./data --rounds 150

# This will create trained model
# Then generate sequences:
from sizzler.models.generator import Generator
gen = Generator(vocab_size=16, ...)  # 16 operators
gen.load_state_dict(torch.load('generator.pth'))

# Generate 6400 sequences of length 154
samples = gen.sample(6400, 154)

# Save to gene.data
with open('gene.data', 'w') as f:
  for seq in samples:
    f.write(' '.join(map(str, seq.tolist())) + '\n')
```

