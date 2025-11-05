# Sizzler Dockerfile
# Multi-stage build for optimized image size

FROM ubuntu:24.04 as builder

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    clang-15 \
    llvm-15 \
    python3.11 \
    python3.11-dev \
    python3-pip \
    wget \
    git \
    && rm -rf /var/lib/apt/lists/*

# Copy AFL source and build
WORKDIR /build
COPY Fuzzing /build/Fuzzing
RUN cd /build/Fuzzing && make clean && make

# Final stage
FROM ubuntu:24.04

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    python3.11 \
    python3-pip \
    clang-15 \
    llvm-15 \
    git \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Create working directory
WORKDIR /sizzler

# Copy AFL binaries from builder
COPY --from=builder /build/Fuzzing /sizzler/Fuzzing

# Copy Python package
COPY pyproject.toml setup.py requirements.txt ./
COPY sizzler ./sizzler
COPY README.md MANIFEST.in ./

# Install Python dependencies and package
# Use --break-system-packages for Ubuntu 24.04 PEP 668 compliance
RUN pip3 install --no-cache-dir --break-system-packages \
    torch>=2.0.0 --index-url https://download.pytorch.org/whl/cpu && \
    pip3 install --no-cache-dir --break-system-packages -e .

# Copy ladder diagrams and other resources
COPY "Ladder Diagram Testbed" ./ladder_diagrams

# Set environment variables
ENV SIZZLER_DATA_PATH=/sizzler/data
ENV PATH="/sizzler/Fuzzing:${PATH}"

# Create directories for fuzzing
RUN mkdir -p /sizzler/data /sizzler/seeds /sizzler/output

# Set working directory
WORKDIR /sizzler

# Default command
CMD ["/bin/bash"]
