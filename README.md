# Sizzler

**Sequential Fuzzing in Ladder Diagrams for Vulnerability Detection in Programmable Logic Controllers**

Sizzler is a hybrid fuzzing tool that combines American Fuzzy Lop (AFL-2.57b) with Sequential Generative Adversarial Networks (Seq-GAN) to improve vulnerability detection in Programmable Logic Controllers (PLCs). It implements a novel mutation strategy enhanced by machine learning to better explore the input space of ladder logic programs.

## Overview

Sizzler focuses on the analysis of executed ladder logic and implements a mutation strategy enhanced by a Seq-GAN formulation used within a fuzzing process. The tool consists of two main components:

1. **AFL Fuzzer** - Modified version of AFL-2.57b for coverage-guided fuzzing
2. **Seq-GAN Module** - PyTorch-based Sequential GAN for intelligent test case generation

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
├── Ladder Diagram Testbed/     # Test cases
├── pyproject.toml             # Modern Python packaging
├── setup.py                   # Backward-compatible setup
├── requirements.txt           # Core dependencies
├── requirements-dev.txt       # Development dependencies
└── README.md                  # This file
```

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

## Contact

For questions and support, please open an issue on the GitHub repository.
