#!/bin/bash

# Comprehensive validation script for StabLab.jl
# Generates reference data from both AllanTools (Python) and MATLAB AllanLab,
# then runs Julia validation comparisons and generates plots.

echo "============================================================"
echo "StabLab.jl Comprehensive Validation Suite"
echo "============================================================"

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
STABLAB_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"

echo "Script directory: $SCRIPT_DIR"
echo "StabLab.jl directory: $STABLAB_DIR"

# Create validation directory if it doesn't exist
mkdir -p "$SCRIPT_DIR"

# Check for required tools
echo ""
echo "Checking required tools..."

# Check Python and AllanTools
if command -v python3 &> /dev/null; then
    echo "✓ Python3 found"
    if python3 -c "import allantools" 2>/dev/null; then
        echo "✓ AllanTools found"
        ALLANTOOLS_AVAILABLE=true
    else
        echo "✗ AllanTools not found. Install with: pip install AllanTools"
        ALLANTOOLS_AVAILABLE=false
    fi
else
    echo "✗ Python3 not found"
    ALLANTOOLS_AVAILABLE=false
fi

# Check MATLAB
MATLAB_PATH="/Applications/MATLAB_R2025a.app/bin/matlab"
if [ -f "$MATLAB_PATH" ]; then
    echo "✓ MATLAB found at $MATLAB_PATH"
    MATLAB_AVAILABLE=true
else
    echo "✗ MATLAB not found at $MATLAB_PATH"
    MATLAB_AVAILABLE=false
fi

# Check Julia
if command -v julia &> /dev/null; then
    echo "✓ Julia found"
    JULIA_AVAILABLE=true
else
    echo "✗ Julia not found"
    JULIA_AVAILABLE=false
    echo "ERROR: Julia is required for validation. Please install Julia."
    exit 1
fi

echo ""
echo "============================================================"
echo "Step 1: Generate AllanTools Reference Data"
echo "============================================================"

if [ "$ALLANTOOLS_AVAILABLE" = true ]; then
    echo "Generating AllanTools reference data..."
    cd "$SCRIPT_DIR"
    
    python3 generate_allantools_reference.py
    
    if [ $? -eq 0 ]; then
        echo "✓ AllanTools reference data generated successfully"
        ALLANTOOLS_REF_AVAILABLE=true
    else
        echo "✗ AllanTools reference generation failed"
        ALLANTOOLS_REF_AVAILABLE=false
    fi
else
    echo "Skipping AllanTools reference generation (not available)"
    ALLANTOOLS_REF_AVAILABLE=false
fi

echo ""
echo "============================================================"
echo "Step 2: Generate MATLAB Reference Data"
echo "============================================================"

if [ "$MATLAB_AVAILABLE" = true ]; then
    echo "Generating MATLAB reference data..."
    cd "$SCRIPT_DIR"
    
    # Run MATLAB script
    "$MATLAB_PATH" -nodisplay -batch "try; generate_matlab_reference(); catch ME; fprintf('ERROR: %s\\n', ME.message); exit(1); end"
    
    if [ $? -eq 0 ]; then
        echo "✓ MATLAB reference data generated successfully"
        MATLAB_REF_AVAILABLE=true
    else
        echo "✗ MATLAB reference generation failed"
        MATLAB_REF_AVAILABLE=false
    fi
else
    echo "Skipping MATLAB reference generation (not available)"
    MATLAB_REF_AVAILABLE=false
fi

echo ""
echo "============================================================"
echo "Step 3: Run Julia Validation Comparisons"
echo "============================================================"

cd "$STABLAB_DIR"

# Test that Julia package loads
echo "Testing Julia package..."
julia -e "using Pkg; Pkg.activate(\".\"); using StabLab; println(\"✓ StabLab.jl loaded successfully\")"

if [ $? -ne 0 ]; then
    echo "✗ Julia package failed to load"
    exit 1
fi

# Run validation scripts based on available reference data
if [ "$ALLANTOOLS_REF_AVAILABLE" = true ]; then
    echo ""
    echo "Running AllanTools comparison..."
    julia validation/compare_with_allantools.jl
    
    if [ $? -eq 0 ]; then
        echo "✓ AllanTools comparison completed"
    else
        echo "✗ AllanTools comparison failed"
    fi
fi

if [ "$MATLAB_REF_AVAILABLE" = true ]; then
    echo ""
    echo "Running MATLAB comparison..."
    julia validation/compare_with_matlab.jl
    
    if [ $? -eq 0 ]; then
        echo "✓ MATLAB comparison completed"
    else
        echo "✗ MATLAB comparison failed"
    fi
fi

# Always run theoretical validation (doesn't need reference data)
echo ""
echo "Running theoretical validation..."
julia validation/theoretical_validation.jl

if [ $? -eq 0 ]; then
    echo "✓ Theoretical validation completed"
else
    echo "✗ Theoretical validation failed"
fi

# Run comprehensive function validation
echo ""
echo "Running comprehensive function validation..."
julia validation/compare_all_functions_matlab.jl

if [ $? -eq 0 ]; then
    echo "✓ Comprehensive validation completed"
else
    echo "✗ Comprehensive validation failed"
fi

echo ""
echo "============================================================"
echo "Validation Summary"
echo "============================================================"

echo "Reference data generation:"
if [ "$ALLANTOOLS_REF_AVAILABLE" = true ]; then
    echo "  ✓ AllanTools reference data available"
else
    echo "  ✗ AllanTools reference data not available"
fi

if [ "$MATLAB_REF_AVAILABLE" = true ]; then
    echo "  ✓ MATLAB reference data available"  
else
    echo "  ✗ MATLAB reference data not available"
fi

echo ""
echo "Generated files in validation/:"
if ls "$SCRIPT_DIR"/*.png 1> /dev/null 2>&1; then
    echo "  Plots:"
    ls -1 "$SCRIPT_DIR"/*.png | sed 's/^/    /'
fi

if ls "$SCRIPT_DIR"/*.json 1> /dev/null 2>&1; then
    echo "  Reference data:"
    ls -1 "$SCRIPT_DIR"/*.json | sed 's/^/    /'
fi

echo ""
echo "Validation complete! Check the files above for detailed results."

# Suggest next steps
echo ""
echo "Next steps:"
echo "  1. Review validation plots for accuracy assessment"
echo "  2. Check console output above for any algorithm warnings"
echo "  3. If needed, fix algorithm discrepancies and re-run validation"
echo "  4. Update documentation with validation results"