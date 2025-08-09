#!/bin/bash

# Comprehensive 3-way benchmark runner
# Tests OADEV, MDEV, OHDEV across Julia, Python, and MATLAB
# 20 datasets × 1M samples each = 20M total samples per language

echo "🚀 COMPREHENSIVE 3-WAY BENCHMARK SUITE"
echo "======================================"
echo "Testing: OADEV, MDEV, OHDEV"
echo "Data: 20 datasets × 1M samples = 20M total per language"
echo "Languages: Julia (StabLab.jl), Python (AllanTools), MATLAB (AllanLab)"
echo ""

# Check if we're in the right directory
if [ ! -f "comprehensive_benchmark.jl" ]; then
    echo "❌ Error: Must run from tests/ directory"
    echo "   cd /path/to/StabLab/tests && ./run_comprehensive_benchmark.sh"
    exit 1
fi

# Clean up any previous results
echo "🧹 Cleaning previous results..."
rm -f /tmp/julia_comprehensive_results.txt
rm -f /tmp/python_comprehensive_results.npz  
rm -f /tmp/matlab_comprehensive_results.mat

echo ""
echo "Starting comprehensive benchmark..."
echo "Expected runtime: ~5-15 minutes total (depends on hardware)"
echo ""

# Track overall timing
overall_start=$(date +%s)

# 1. Julia StabLab.jl benchmark (fair comparison)
echo "=== 1/3: Julia StabLab.jl (Fair) ==="
echo "Starting Julia fair benchmark (simple CI)..."
julia_start=$(date +%s)

julia fair_benchmark.jl
julia_exit_code=$?

julia_end=$(date +%s)
julia_time=$((julia_end - julia_start))

if [ $julia_exit_code -ne 0 ]; then
    echo "❌ Julia benchmark failed!"
    exit 1
fi

echo "✅ Julia fair benchmark completed in ${julia_time}s"
echo ""

# 2. Python AllanTools benchmark  
echo "=== 2/3: Python AllanTools ==="
echo "Starting Python benchmark..."
python_start=$(date +%s)

python3 comprehensive_benchmark.py
python_exit_code=$?

python_end=$(date +%s)
python_time=$((python_end - python_start))

if [ $python_exit_code -ne 0 ]; then
    echo "❌ Python benchmark failed!"
    exit 1
fi

echo "✅ Python completed in ${python_time}s"
echo ""

# 3. MATLAB AllanLab benchmark
echo "=== 3/3: MATLAB AllanLab ==="
echo "Starting MATLAB benchmark..."
matlab_start=$(date +%s)

# Check if MATLAB is available
if ! command -v matlab &> /dev/null; then
    echo "⚠️  MATLAB not found in PATH, trying full path..."
    MATLAB_PATH="/Applications/MATLAB_R2025a.app/bin/matlab"
    if [ ! -f "$MATLAB_PATH" ]; then
        echo "❌ MATLAB not found at $MATLAB_PATH"
        echo "   Skipping MATLAB benchmark"
        matlab_time=0
    else
        $MATLAB_PATH -nodisplay -nosplash -nodesktop -r "addpath('/Users/ianlapinski/Desktop/masterclock-kflab/matlab/AllanLab'); comprehensive_benchmark; exit"
        matlab_exit_code=$?
        
        matlab_end=$(date +%s)
        matlab_time=$((matlab_end - matlab_start))
        
        if [ $matlab_exit_code -ne 0 ]; then
            echo "❌ MATLAB benchmark failed!"
            exit 1
        fi
        
        echo "✅ MATLAB completed in ${matlab_time}s"
    fi
else
    matlab -nodisplay -nosplash -nodesktop -r "addpath('/Users/ianlapinski/Desktop/masterclock-kflab/matlab/AllanLab'); comprehensive_benchmark; exit"
    matlab_exit_code=$?
    
    matlab_end=$(date +%s)
    matlab_time=$((matlab_end - matlab_start))
    
    if [ $matlab_exit_code -ne 0 ]; then
        echo "❌ MATLAB benchmark failed!"
        exit 1
    fi
    
    echo "✅ MATLAB completed in ${matlab_time}s"
fi

echo ""

# Overall summary
overall_end=$(date +%s)
overall_time=$((overall_end - overall_start))

echo "🏁 COMPREHENSIVE BENCHMARK COMPLETE"
echo "=================================="
echo ""
echo "Execution Summary:"
echo "  Julia (StabLab.jl):     ${julia_time}s"
echo "  Python (AllanTools):    ${python_time}s"
if [ $matlab_time -gt 0 ]; then
    echo "  MATLAB (AllanLab):      ${matlab_time}s"
fi
echo "  Total time:             ${overall_time}s ($(($overall_time / 60)) min)"
echo ""

# Performance comparison (if all completed)
if [ $matlab_time -gt 0 ]; then
    echo "Performance Ranking (faster is better):"
    
    # Simple ranking by total time
    if [ $julia_time -le $python_time ] && [ $julia_time -le $matlab_time ]; then
        fastest="Julia"
        if [ $python_time -le $matlab_time ]; then
            echo "  1st: Julia (${julia_time}s) 🥇"
            echo "  2nd: Python (${python_time}s) 🥈" 
            echo "  3rd: MATLAB (${matlab_time}s) 🥉"
        else
            echo "  1st: Julia (${julia_time}s) 🥇"
            echo "  2nd: MATLAB (${matlab_time}s) 🥈"
            echo "  3rd: Python (${python_time}s) 🥉"
        fi
    elif [ $python_time -le $julia_time ] && [ $python_time -le $matlab_time ]; then
        fastest="Python"
        if [ $julia_time -le $matlab_time ]; then
            echo "  1st: Python (${python_time}s) 🥇"
            echo "  2nd: Julia (${julia_time}s) 🥈"
            echo "  3rd: MATLAB (${matlab_time}s) 🥉"
        else
            echo "  1st: Python (${python_time}s) 🥇"
            echo "  2nd: MATLAB (${matlab_time}s) 🥈"
            echo "  3rd: Julia (${julia_time}s) 🥉"
        fi
    else
        fastest="MATLAB"
        if [ $julia_time -le $python_time ]; then
            echo "  1st: MATLAB (${matlab_time}s) 🥇"
            echo "  2nd: Julia (${julia_time}s) 🥈"
            echo "  3rd: Python (${python_time}s) 🥉"
        else
            echo "  1st: MATLAB (${matlab_time}s) 🥇"
            echo "  2nd: Python (${python_time}s) 🥈"
            echo "  3rd: Julia (${julia_time}s) 🥉"
        fi
    fi
    
    echo ""
    echo "Winner: $fastest is the fastest! 🏆"
else
    echo "Performance Comparison (Julia vs Python only):"
    if [ $julia_time -le $python_time ]; then
        speedup=$(echo "scale=2; $python_time / $julia_time" | bc)
        echo "  Julia: ${julia_time}s 🥇"
        echo "  Python: ${python_time}s 🥈"
        echo "  Julia is ${speedup}x faster than Python"
    else
        speedup=$(echo "scale=2; $julia_time / $python_time" | bc)
        echo "  Python: ${python_time}s 🥇"
        echo "  Julia: ${julia_time}s 🥈"
        echo "  Python is ${speedup}x faster than Julia"
    fi
fi

echo ""
echo "📊 Results saved to:"
echo "  Julia:  /tmp/julia_comprehensive_results.txt"
echo "  Python: /tmp/python_comprehensive_results.npz"
if [ $matlab_time -gt 0 ]; then
    echo "  MATLAB: /tmp/matlab_comprehensive_results.mat"
fi

echo ""
echo "✅ 3-way comprehensive benchmark completed successfully!"
echo "   Ready to push StabLab.jl v0.4.0! 🚀"