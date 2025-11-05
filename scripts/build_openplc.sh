#!/bin/bash
################################################################################
# OpenPLC Build Automation Script for Sizzler
#
# This script automates fetching, building, and setting up OpenPLC v3
# for use with AFL fuzzing and the Sizzler vulnerability testing framework.
#
# Usage: ./build_openplc.sh [install_dir]
#
# Default install_dir: /tmp/OpenPLC_v3
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="${1:-/tmp/OpenPLC_v3}"
OPENPLC_REPO="https://github.com/thiagoralves/OpenPLC_v3.git"
SIZZLER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Progress indicator
print_section() {
    echo ""
    echo "========================================================================"
    echo "  $1"
    echo "========================================================================"
    echo ""
}

################################################################################
# Check Prerequisites
################################################################################
check_prerequisites() {
    print_section "Checking Prerequisites"

    local missing_deps=()

    for cmd in git gcc g++ make cmake autoconf automake libtool flex bison; do
        if ! command -v $cmd &> /dev/null; then
            missing_deps+=($cmd)
        fi
    done

    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_info "Please install them with:"
        log_info "  sudo apt-get install -y build-essential git cmake autoconf automake libtool flex bison"
        exit 1
    fi

    log_success "All prerequisites satisfied"
}

################################################################################
# Clone OpenPLC Repository
################################################################################
clone_openplc() {
    print_section "Cloning OpenPLC Repository"

    if [ -d "$INSTALL_DIR" ]; then
        log_warning "OpenPLC directory already exists: $INSTALL_DIR"
        read -p "Delete and re-clone? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Removing existing directory..."
            rm -rf "$INSTALL_DIR"
        else
            log_info "Using existing directory"
            return 0
        fi
    fi

    log_info "Cloning OpenPLC from $OPENPLC_REPO..."
    git clone --depth=1 "$OPENPLC_REPO" "$INSTALL_DIR"

    log_success "OpenPLC cloned to $INSTALL_DIR"
}

################################################################################
# Build MATIEC (IEC 61131-3 to C Compiler)
################################################################################
build_matiec() {
    print_section "Building MATIEC (iec2c compiler)"

    local MATIEC_DIR="$INSTALL_DIR/utils/matiec_src"

    log_info "Configuring MATIEC..."
    cd "$MATIEC_DIR"

    # Generate configure script
    log_info "Running autoreconf..."
    autoreconf -i

    # Configure
    log_info "Running configure..."
    ./configure

    # Build
    log_info "Building MATIEC (this may take a minute)..."
    make -j4

    # Check if iec2c was built
    if [ ! -f "$MATIEC_DIR/iec2c" ]; then
        log_error "Failed to build iec2c"
        exit 1
    fi

    # Copy to webserver directory
    log_info "Installing iec2c to webserver directory..."
    cp "$MATIEC_DIR/iec2c" "$INSTALL_DIR/webserver/"

    log_success "MATIEC built successfully: $MATIEC_DIR/iec2c"
}

################################################################################
# Build Glue Generator
################################################################################
build_glue_generator() {
    print_section "Building Glue Generator"

    local GLUE_DIR="$INSTALL_DIR/utils/glue_generator_src"

    log_info "Building glue generator..."
    cd "$GLUE_DIR"

    # Build using CMake
    mkdir -p build
    cd build

    log_info "Configuring with CMake..."
    cmake .. -DOPLCGLUE_TEST=OFF  # Skip tests to avoid build errors

    # Build just the main binary
    log_info "Compiling glue_generator..."
    make glue_generator || {
        log_warning "CMake build failed, trying direct compilation..."
        cd "$GLUE_DIR"
        g++ -std=c++11 -o glue_generator glue_generator.cpp
        mkdir -p bin
        mv glue_generator bin/
    }

    # Check if glue_generator was built
    local GLUE_BIN="$GLUE_DIR/bin/glue_generator"
    if [ ! -f "$GLUE_BIN" ]; then
        log_error "Failed to build glue_generator"
        exit 1
    fi

    # Copy to webserver/core directory
    log_info "Installing glue_generator to core directory..."
    cp "$GLUE_BIN" "$INSTALL_DIR/webserver/core/"

    log_success "Glue generator built successfully: $GLUE_BIN"
}

################################################################################
# Setup OpenPLC Environment
################################################################################
setup_environment() {
    print_section "Setting Up OpenPLC Environment"

    local SCRIPTS_DIR="$INSTALL_DIR/webserver/scripts"

    # Set platform to Linux
    echo "linux" > "$SCRIPTS_DIR/openplc_platform"
    log_info "Platform set to: linux"

    # Set default driver (blank for standard)
    echo "blank" > "$SCRIPTS_DIR/openplc_driver"
    log_info "Driver set to: blank (standard)"

    # Disable EtherCAT by default
    echo "" > "$SCRIPTS_DIR/ethercat"
    log_info "EtherCAT: disabled"

    log_success "OpenPLC environment configured"
}

################################################################################
# Create AFL-instrumented Compilation Script
################################################################################
create_afl_compile_script() {
    print_section "Creating AFL-Instrumented Compilation Script"

    local AFL_SCRIPT="$INSTALL_DIR/webserver/scripts/compile_program_afl.sh"
    local ORIGINAL_SCRIPT="$INSTALL_DIR/webserver/scripts/compile_program.sh"

    log_info "Creating AFL-instrumented compilation script..."

    # Copy original and modify to use afl-g++
    cp "$ORIGINAL_SCRIPT" "$AFL_SCRIPT"

    # Replace g++ with AFL's instrumented compiler
    sed -i "s|g++ |$SIZZLER_ROOT/Fuzzing/afl-g++ |g" "$AFL_SCRIPT"

    chmod +x "$AFL_SCRIPT"

    log_success "AFL compilation script created: $AFL_SCRIPT"
    log_info "To compile with AFL instrumentation, use: $AFL_SCRIPT <program.st>"
}

################################################################################
# Verify Build
################################################################################
verify_build() {
    print_section "Verifying Build"

    local all_good=true

    # Check iec2c
    if [ -f "$INSTALL_DIR/webserver/iec2c" ]; then
        log_success "iec2c: OK"
    else
        log_error "iec2c: MISSING"
        all_good=false
    fi

    # Check glue_generator
    if [ -f "$INSTALL_DIR/webserver/core/glue_generator" ]; then
        log_success "glue_generator: OK"
    else
        log_error "glue_generator: MISSING"
        all_good=false
    fi

    # Check compilation scripts
    if [ -f "$INSTALL_DIR/webserver/scripts/compile_program.sh" ]; then
        log_success "compile_program.sh: OK"
    else
        log_error "compile_program.sh: MISSING"
        all_good=false
    fi

    if [ -f "$INSTALL_DIR/webserver/scripts/compile_program_afl.sh" ]; then
        log_success "compile_program_afl.sh: OK (AFL-instrumented)"
    else
        log_error "compile_program_afl.sh: MISSING"
        all_good=false
    fi

    if [ "$all_good" = true ]; then
        log_success "All components verified successfully!"
    else
        log_error "Some components are missing - build may have failed"
        exit 1
    fi
}

################################################################################
# Print Summary
################################################################################
print_summary() {
    print_section "Build Summary"

    cat << EOF
${GREEN}OpenPLC has been successfully built and configured!${NC}

Installation Directory: ${BLUE}$INSTALL_DIR${NC}

Key Components:
  iec2c compiler:        $INSTALL_DIR/webserver/iec2c
  glue_generator:        $INSTALL_DIR/webserver/core/glue_generator
  Standard compile:      $INSTALL_DIR/webserver/scripts/compile_program.sh
  AFL-instrumented:      $INSTALL_DIR/webserver/scripts/compile_program_afl.sh

Next Steps:
  1. Convert ladder diagrams to Structured Text (.st files)
  2. Compile with AFL instrumentation using compile_program_afl.sh
  3. Fuzz test with AFL + Seq-GAN using Sizzler

Example Usage:
  # Convert .ld to .st (may require LDmicro or manual conversion)
  # Place .st file in: $INSTALL_DIR/webserver/st_files/

  # Compile with AFL instrumentation
  cd $INSTALL_DIR/webserver
  ./scripts/compile_program_afl.sh your_program.st

  # The instrumented binary will be: $INSTALL_DIR/webserver/core/openplc

  # Run AFL fuzzing with Sizzler Seq-GAN
  export SIZZLER_SEQGAN_DATA="$SIZZLER_ROOT/data/gene.data"
  $SIZZLER_ROOT/Fuzzing/afl-fuzz -i seeds -o output -m none \\
      $INSTALL_DIR/webserver/core/openplc

For more information, see:
  - Sizzler documentation: $SIZZLER_ROOT/SIZZLER_ARCHITECTURE.md
  - OpenPLC documentation: https://www.openplcproject.com/

EOF
}

################################################################################
# Main Execution
################################################################################
main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║         OpenPLC Build Script for Sizzler Framework                 ║"
    echo "║         Automated build and configuration                          ║"
    echo "╚════════════════════════════════════════════════════════════════════╝"
    echo ""

    check_prerequisites
    clone_openplc
    build_matiec
    build_glue_generator
    setup_environment
    create_afl_compile_script
    verify_build
    print_summary

    log_success "OpenPLC build completed successfully!"
}

# Run main function
main "$@"
