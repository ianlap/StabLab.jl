#!/bin/bash

# Mega Benchmark Script: Run all three implementations
# Tests Julia StabLab.jl vs Python AllanTools vs MATLAB AllanLab
# 30 datasets x 10^7 samples each = 3x10^8 total samples

set -e  # Exit on error

echo "========================================="
echo "MEGA BENCHMARK: Three-Way Comparison"
echo "========================================="
echo "Testing: ADEV, MDEV, HDEV"
echo "Data: 30 datasets x 10M samples = 300M total samples"
echo "Languages: Python (AllanTools) vs Julia (StabLab.jl) vs MATLAB (AllanLab)"
echo ""

# Set up directories and paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMP_DIR="/tmp"
MATLAB_BIN="/Applications/MATLAB_R2025a.app/bin/matlab"

echo "Script directory: $SCRIPT_DIR"
echo "Results will be saved to: $TEMP_DIR"
echo ""

# Check if all required files exist
check_files() {
    echo "Checking required files..."
    
    local files=(
        "mega_benchmark_python.py"
        "mega_benchmark_julia.jl"
        "mega_benchmark_matlab.m"
    )
    
    for file in "${files[@]}"; do
        if [[ ! -f "$SCRIPT_DIR/$file" ]]; then
            echo "ERROR: $file not found in $SCRIPT_DIR"
            exit 1
        fi
        echo "  ✓ $file"
    done
    
    # Check MATLAB
    if [[ ! -f "$MATLAB_BIN" ]]; then
        echo "ERROR: MATLAB not found at $MATLAB_BIN"
        echo "Please update the path in this script"
        exit 1
    fi
    echo "  ✓ MATLAB at $MATLAB_BIN"
    
    echo ""
}

# Clean up previous results
cleanup_previous() {
    echo "Cleaning up previous results..."
    
    local temp_files=(
        "$TEMP_DIR/python_mega_benchmark_log.txt"
        "$TEMP_DIR/python_mega_benchmark_results.txt"
        "$TEMP_DIR/python_mega_benchmark_plots.png"
        "$TEMP_DIR/python_mega_results.npz"
        "$TEMP_DIR/mega_benchmark_data.npy"
        "$TEMP_DIR/julia_mega_benchmark_log.txt"
        "$TEMP_DIR/julia_mega_benchmark_results.txt"
        "$TEMP_DIR/julia_mega_benchmark_plots.png"
        "$TEMP_DIR/julia_mega_results.npz"
        "$TEMP_DIR/matlab_mega_benchmark_log.txt"
        "$TEMP_DIR/matlab_mega_benchmark_results.txt"
        "$TEMP_DIR/matlab_mega_results.mat"
    )
    
    for file in "${temp_files[@]}"; do
        if [[ -f "$file" ]]; then
            rm "$file"
            echo "  Removed $file"
        fi
    done
    
    echo ""
}

# Run Python benchmark
run_python_benchmark() {
    echo "========================================="
    echo "PHASE 1: Python AllanTools Benchmark"
    echo "========================================="
    echo ""
    
    cd "$SCRIPT_DIR"
    echo "Starting Python benchmark..."
    echo "This will take several minutes for 10M samples x 30 datasets"
    echo ""
    
    local start_time=$(date +%s)
    
    if python3 mega_benchmark_python.py; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo ""
        echo "Python benchmark completed in ${duration}s"
        echo ""
    else
        echo "ERROR: Python benchmark failed"
        exit 1
    fi
}

# Run Julia benchmark
run_julia_benchmark() {
    echo "========================================="
    echo "PHASE 2: Julia StabLab.jl Benchmark"
    echo "========================================="
    echo ""
    
    cd "$SCRIPT_DIR"
    echo "Starting Julia benchmark..."
    echo "Using same 30 datasets for fair comparison"
    echo ""
    
    local start_time=$(date +%s)
    
    if julia mega_benchmark_julia.jl; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo ""
        echo "Julia benchmark completed in ${duration}s"
        echo ""
    else
        echo "ERROR: Julia benchmark failed"
        exit 1
    fi
}

# Run MATLAB benchmark
run_matlab_benchmark() {
    echo "========================================="
    echo "PHASE 3: MATLAB AllanLab Benchmark"
    echo "========================================="
    echo ""
    
    cd "$SCRIPT_DIR"
    echo "Starting MATLAB benchmark..."
    echo "This may take the longest due to MATLAB overhead"
    echo ""
    
    local start_time=$(date +%s)
    
    # Create MATLAB script that loads reference data and runs benchmark
    if "$MATLAB_BIN" -nodisplay -r "cd('$SCRIPT_DIR'); mega_benchmark_matlab(); exit"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo ""
        echo "MATLAB benchmark completed in ${duration}s"
        echo ""
    else
        echo "ERROR: MATLAB benchmark failed"
        exit 1
    fi
}

# Generate final comparison report
generate_comparison_report() {
    echo "========================================="
    echo "FINAL COMPARISON REPORT"
    echo "========================================="
    echo ""
    
    # Create comprehensive report
    local report_file="$TEMP_DIR/mega_benchmark_comparison_report.txt"
    
    cat > "$report_file" << EOF
MEGA BENCHMARK COMPARISON REPORT
========================================
Test Configuration:
- Dataset size: 10,000,000 samples per dataset
- Number of datasets: 30
- Total samples processed: 300,000,000
- Functions tested: ADEV, MDEV, HDEV
- Data type: White FM noise (random walk phase)

========================================
RESULTS SUMMARY
========================================

EOF
    
    # Add individual results if they exist
    if [[ -f "$TEMP_DIR/python_mega_benchmark_results.txt" ]]; then
        echo "PYTHON ALLANTOOLS:" >> "$report_file"
        tail -n 10 "$TEMP_DIR/python_mega_benchmark_results.txt" >> "$report_file"
        echo "" >> "$report_file"
    fi
    
    if [[ -f "$TEMP_DIR/julia_mega_benchmark_results.txt" ]]; then
        echo "JULIA STABLAB:" >> "$report_file"
        tail -n 10 "$TEMP_DIR/julia_mega_benchmark_results.txt" >> "$report_file"
        echo "" >> "$report_file"
    fi
    
    if [[ -f "$TEMP_DIR/matlab_mega_benchmark_results.txt" ]]; then
        echo "MATLAB ALLANLAB:" >> "$report_file"
        tail -n 10 "$TEMP_DIR/matlab_mega_benchmark_results.txt" >> "$report_file"
        echo "" >> "$report_file"
    fi
    
    echo "========================================" >> "$report_file"
    echo "FILES GENERATED:" >> "$report_file"
    echo "========================================" >> "$report_file"
    
    for file in "$TEMP_DIR"/*mega_benchmark* "$TEMP_DIR"/*mega_results*; do
        if [[ -f "$file" ]]; then
            echo "$(basename "$file")" >> "$report_file"
        fi
    done
    
    echo ""
    echo "Comparison report saved to: $report_file"
    echo ""
    echo "Generated files:"
    for file in "$TEMP_DIR"/*mega_benchmark* "$TEMP_DIR"/*mega_results*; do
        if [[ -f "$file" ]]; then
            echo "  $(basename "$file")"
        fi
    done
    
    echo ""
    echo "View the complete results:"
    echo "  cat $report_file"
    echo ""
}

# Main execution
main() {
    local total_start_time=$(date +%s)
    
    # Check prerequisites
    check_files
    
    # Clean up
    cleanup_previous
    
    # Run benchmarks in sequence
    run_python_benchmark
    run_julia_benchmark
    run_matlab_benchmark
    
    # Generate final report
    generate_comparison_report
    
    local total_end_time=$(date +%s)
    local total_duration=$((total_end_time - total_start_time))
    local total_minutes=$((total_duration / 60))
    local remaining_seconds=$((total_duration % 60))
    
    echo "========================================="
    echo "BENCHMARK COMPLETE"
    echo "========================================="
    echo "Total execution time: ${total_minutes}m ${remaining_seconds}s"
    echo ""
    echo "All three implementations have been benchmarked!"
    echo "Check the generated reports and plots for detailed comparison."
}

# Run the benchmark
main "$@"