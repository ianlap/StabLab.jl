# StabLab.jl Directory Structure

This document provides a reference for the project organization and file purposes.

## Root Directory
```
StabLab.jl/
├── CHANGELOG.md              # Version history and release notes
├── CLAUDE.md                 # Development guidance for Claude Code
├── DIRECTORY_STRUCTURE.md    # This file - project organization reference
├── Manifest.toml            # Exact package dependencies (Julia-generated)
├── Project.toml             # Package metadata and dependencies
├── README.md                # Main project documentation
└── .gitignore              # Git ignore patterns
```

## Core Source Code (`src/`)
```
src/
├── StabLab.jl               # Main module file with exports
├── core.jl                  # Input validation and utility functions
├── deviations.jl            # All 10 NIST deviation implementations
├── time_error.jl            # TIE, MTIE, PDEV, THEO1 functions
├── confidence.jl            # EDF calculation and confidence intervals + bias correction
├── noise.jl                 # Noise identification (placeholder for KalmanFilterToolbox)
└── plotting.jl              # Plotting utilities and report generation
```

## Test Suite (`tests/`)
**Unit and integration tests only** - keep focused and fast

```
tests/
├── test_basic.jl            # Basic functionality tests
├── test_complete.jl         # Full test suite runner
├── test_all_10_deviations.jl # Tests all deviation functions
├── test_confidence.jl       # Confidence interval testing
├── test_helper_functions.jl # EDF, noise_id, etc.
├── test_time_errors.jl      # TIE/MTIE/PDEV/THEO1 tests
├── test_slopes.jl           # Mathematical relationship validation
├── test_tdev_ldev.jl        # Time-domain deviation tests
└── test_*.jl               # Individual function tests (hdev, mhdev, etc.)
```

## Performance Benchmarks (`benchmarks/`)
**Performance comparison and optimization** - can be slower

```
benchmarks/
├── run_mega_benchmark.sh    # Automated 3-way comparison script
├── benchmark_julia.jl       # Pure Julia performance tests
├── benchmark_matlab.m       # MATLAB comparison scripts
├── benchmark_vs_allantools.py # Python/AllanTools comparison
├── comprehensive_benchmark.* # Multi-language comprehensive comparison
├── simple_comparison.jl     # Quick performance check
└── profile_performance.jl   # Julia profiling and optimization
```

## Validation Suite (`validation/`)
**Algorithm accuracy verification** - uses real datasets

```
validation/
├── data/                    # Real test datasets (6krbsnip.txt, etc.)
├── run_comprehensive_validation.sh # Master validation script
├── generate_*_reference.*   # Generate reference data from MATLAB/AllanTools
├── compare_*.jl            # Comparison scripts vs reference implementations
├── theoretical_validation.jl # Mathematical relationship validation
├── debug_*.jl              # Debugging specific algorithm issues
└── test_*_comprehensive.jl  # Full validation on real datasets
```

## Usage Examples (`examples/`)
**Documentation and tutorial code** - user-facing

```
examples/
├── basic_usage.jl           # Simple getting-started example
├── plotting_example.jl      # How to create deviation plots
├── 6krb25apr.txt           # Sample rubidium clock data
├── *.png                   # Generated example plots
└── validate_time_errors_visual.jl # Time error function demonstrations
```

## Generated Results (`results/`)
**Output files from benchmarks and validation** - gitignored

```
results/
├── *.png                   # Generated plots and figures
├── *.json                  # Benchmark and comparison data
├── benchmark_results_*     # Performance comparison results
└── validation_results_*    # Algorithm accuracy results
```

## Key Design Principles

### File Organization Rules
1. **Source (`src/`)**: Only core library code, well-tested and optimized
2. **Tests (`tests/`)**: Fast unit tests, run frequently during development  
3. **Benchmarks (`benchmarks/`)**: Performance comparisons, can be slow
4. **Validation (`validation/`)**: Algorithm accuracy using real data
5. **Examples (`examples/`)**: User documentation and tutorials
6. **Results (`results/`)**: Generated outputs, not committed to git

### Function Organization by File
- **`deviations.jl`**: ADEV, MDEV, HDEV, MHDEV, TOTDEV, MTOTDEV, HTOTDEV, MHTOTDEV, TDEV, LDEV
- **`time_error.jl`**: TIE, MTIE, PDEV, THEO1 (added in v0.5.0)
- **`confidence.jl`**: EDF calculation, confidence intervals, bias correction
- **`core.jl`**: Input validation, default parameters, utility functions
- **`plotting.jl`**: Plot generation, report formatting

### Deprecated/Removed Files
The following were removed during reorganization:
- Individual test files in root directory
- Duplicate benchmark scripts  
- Temporary validation scripts
- Old comparison files with hardcoded reference data

### File Naming Conventions
- **`test_*.jl`**: Unit tests for specific functions
- **`benchmark_*.jl`**: Performance measurement scripts
- **`compare_*.jl`**: Algorithm accuracy comparison scripts  
- **`validate_*.jl`**: Validation using real datasets
- **`generate_*.py|.m`**: Reference data generation scripts
- **`debug_*.jl`**: Troubleshooting specific issues

### Data Files
- **Real datasets**: `validation/data/` (6krbsnip.txt, mx.w10.pem7, etc.)
- **Example data**: `examples/` (small samples for tutorials)
- **Generated data**: `results/` (not committed, recreated as needed)

## Quick Reference

**To run basic tests**: `julia tests/test_complete.jl`
**To benchmark performance**: `julia benchmarks/simple_comparison.jl`  
**To validate accuracy**: `./validation/run_comprehensive_validation.sh`
**For usage examples**: See `examples/basic_usage.jl`
**For algorithm debugging**: Use scripts in `validation/debug_*.jl`

## Maintenance Notes

- Keep `tests/` fast and focused on correctness
- Use `benchmarks/` for performance optimization
- Use `validation/` for algorithm accuracy verification
- Update this document when adding/removing files
- Remove obsolete files to prevent confusion
- Document the purpose of new files added