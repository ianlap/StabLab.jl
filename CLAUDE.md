# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with StabLab.jl.

## StabLab.jl - Frequency Stability Analysis Library

### Running Tests
```bash
# Basic functionality test
julia test_complete.jl

# Test all 10 deviation functions
julia test_all_10_deviations.jl

# Individual function tests
julia test_hdev.jl
julia test_mhtotdev.jl
julia test_totdev.jl
```

### Benchmarking & Validation

#### MATLAB Reference
- **MATLAB Location**: `/Applications/MATLAB_R2025a.app/bin/matlab`
- **AllanLab Reference**: `/Users/ianlapinski/Desktop/masterclock-kflab/matlab/AllanLab/`
- **Run MATLAB script**: 
  ```bash
  /Applications/MATLAB_R2025a.app/bin/matlab -nodisplay -r "script_name; exit"
  ```

#### Python Reference (AllanTools)
- **AllanTools Location**: `/Users/ianlapinski/Desktop/masterclock-kflab/allantools/`
- **Run benchmark**: `python3 benchmark_vs_allantools.py`

#### Julia Performance
- **Simple test**: `julia simple_comparison.jl`
- **Large dataset benchmark**: `julia benchmark_julia.jl`

### Available Deviation Functions

StabLab.jl implements all 10 NIST SP1065 deviation types:

1. **adev** - Allan deviation (fundamental stability measure)
2. **mdev** - Modified Allan deviation (removes dead time effects)
3. **mhdev** - Modified Hadamard deviation (robust against drift)
4. **hdev** - Hadamard deviation (overlapping third differences)
5. **mhtotdev** - Modified Hadamard total deviation (all samples + detrending)
6. **tdev** - Time deviation (time-domain Allan measure, returns seconds)
7. **ldev** - Lapinski deviation (time-domain Hadamard measure, returns seconds)
8. **totdev** - Total deviation (all samples with detrending)
9. **mtotdev** - Modified total deviation (half-average detrending)
10. **htotdev** - Hadamard total deviation (SP1065 detrending method)

### Usage Examples
```julia
using StabLab

# Generate test data
phase_data = cumsum(randn(1000)) * 1e-9
tau0 = 1.0

# Single return (recommended)
result = adev(phase_data, tau0)

# Multiple returns (MATLAB-style)
tau, dev = adev(phase_data, tau0, Val(2))
tau, dev, edf = adev(phase_data, tau0, Val(3))

# Custom parameters
result = adev(phase_data, tau0, mlist=[1,2,4,8], confidence=0.95)
```

### Mathematical Relationships
- **TDEV = τ × MDEV / √3** (verified in tests)
- **LDEV = τ × MHDEV / √(10/3)** (verified in tests)

### Project Structure
- `src/StabLab.jl` - Main module with exports
- `src/core.jl` - Validation and utility functions  
- `src/deviations.jl` - All 10 deviation implementations
- `src/noise.jl` - Noise identification (placeholder)
- `src/confidence.jl` - Confidence interval computation (placeholder)
- `tests/` - Test scripts and validation
  - `test_*.jl` - Individual function tests
  - `benchmark_*.py|jl|m` - Performance comparison scripts
  - `run_mega_benchmark.sh` - Three-way benchmark runner
- `examples/` - Usage examples and demonstrations
- `CLAUDE.md` - Development guidance and known issues

### File Organization Guidelines
- **Keep root directory clean**: Only essential files (Project.toml, README.md, CLAUDE.md)
- **Tests go in tests/**: All test scripts, benchmarks, and validation code
- **Examples go in examples/**: Usage demonstrations, tutorials, and showcase code
- **Remove temporary test files**: Don't keep one-off test scripts in root
- **Benchmark scripts are showcase worthy**: Keep performance comparisons as they demonstrate capabilities

### Development Notes
- All algorithms translated exactly from MATLAB AllanLab
- Supports both frequency (dimensionless) and time-domain deviations
- Type-safe implementations with comprehensive validation
- Consistent API across all functions with multiple dispatch patterns
- Ready for integration with KalmanFilterToolbox.jl

## Common Issues & Solutions

### Julia Package Compilation Warnings
**Issue**: `Statistics` package fails to load from cache
```
┌ Warning: The call to compilecache failed to create a usable precompiled cache file for StabLab
│   exception = Required dependency Statistics failed to load from a cache file.
```
**Solution**: This is a known Julia warning that doesn't affect functionality. The package still works correctly.

### Variable Scoping in Scripts
**Issue**: `UndefVarError` in global scope when using variables in loops
```julia
# ❌ This fails in global scope:
total_time = 0.0
for item in items
    total_time += some_value  # UndefVarError
end
```
**Solution**: Use `global` keyword in loops that modify outer variables
```julia
# ✅ This works:
global total_time = 0.0
for item in items
    global total_time += some_value
end
```

### String Interpolation Issues
**Issue**: Complex expressions in string interpolation can cause scoping issues
```julia
# ❌ This can fail:
println("Range: [$(minimum(data):.2e), $(maximum(data):.2e)]")
```
**Solution**: Extract expressions to variables first
```julia
# ✅ This works:
min_val = minimum(data)
max_val = maximum(data)
println("Range: [$min_val, $max_val]")
```

### NPZ/NumPy File Loading
**Issue**: Reading large NPY files can cause memory or format issues
**Solution**: Use smaller test datasets or save/load as Julia native formats
```julia
# For large benchmarks, use smaller N (e.g., 500k instead of 5M)
N = 500000  # Works well for benchmarking
```

### Function Documentation Syntax
**Issue**: Using Python-style triple quotes in Julia functions
```julia
# ❌ This is Python syntax:
function foo()
    """This is wrong"""
```
**Solution**: Use Julia comment syntax or proper docstrings
```julia
# ✅ This is correct:
function foo()
    # This is a comment
```

## Performance Benchmarks (Reference)
- **Julia StabLab.jl** (500k samples): 2.473s total (ADEV: 0.916s, MDEV: 0.95s, HDEV: 0.607s)
- **Python AllanTools** (5M samples): 4.668s total (ADEV: 0.990s, MDEV: 2.231s, HDEV: 1.447s)
- **Julia is ~1.9x faster** than Python for equivalent computations
- **Throughput**: ~0.61 Msamples/sec on test hardware

## Debugging Workflow
1. **Start small**: Test with small datasets (N=1000-10000) before scaling up
2. **Use simple_comparison.jl**: Quick validation of all functions
3. **Check variable scoping**: Use `global` keyword when modifying variables in loops
4. **Isolate issues**: If complex benchmarks fail, test individual functions first
5. **Reference implementations**: Compare against MATLAB/Python results for validation

## Code Style Notes
- **Avoid emojis**: Use plain text for output messages and logging
- **Professional output**: Keep console output clean and readable
- **Consistent formatting**: Use standard text formatting rather than special characters