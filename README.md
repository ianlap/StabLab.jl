# StabLab.jl

A Julia package for frequency stability analysis implementing deviation calculations based on NIST Special Publication 1065. StabLab.jl provides fast, accurate statistical measures for analyzing oscillator stability through various deviation types including Allan, Hadamard, and Time deviations.

## Features

### 📊 **Complete NIST SP1065 Deviation Suite**
All 10 deviation types implemented:
- **`adev()`** - Allan deviation - fundamental stability measure
- **`mdev()`** - Modified Allan deviation - removes dead time effects
- **`mhdev()`** - Modified Hadamard deviation - robust against frequency drift
- **`hdev()`** - Hadamard deviation - overlapping third differences
- **`mhtotdev()`** - Modified Hadamard total deviation - all samples + detrending
- **`tdev()`** - Time deviation - time-domain Allan measure (seconds)
- **`ldev()`** - Lapinski deviation - time-domain Hadamard measure (seconds)
- **`totdev()`** - Total deviation - uses all overlapping samples with detrending
- **`mtotdev()`** - Modified total deviation - half-average detrending
- **`htotdev()`** - Hadamard total deviation - SP1065 detrending method

### ⚡ **Performance & Accuracy**
- **Exact algorithm translation** from validated MATLAB implementations
- **High-performance Julia implementation** - ~1.9x faster than Python AllanTools
- **Validated against theory** - slopes match expected values for different noise types
- **Cross-platform verified** - results match MATLAB AllanLab and Python AllanTools
- **Memory efficient** - Optimized algorithms with minimal allocation
- **Scalable** - tested with datasets up to 10^7 samples

### 🎯 **Modern Julia API**
- **Flexible returns**: Single struct output or multiple values
- **Keyword arguments**: Custom averaging factors (`mlist`) and confidence levels
- **Type-safe**: Comprehensive input validation and error handling
- **Clean interface**: Consistent API across all deviation functions

## Installation

```julia
# Navigate to package directory and activate
using Pkg
Pkg.activate("/path/to/StabLab")
```

## Quick Start

### Basic Usage

```julia
using StabLab
using Random

# Generate example data
Random.seed!(42)
N = 1000
phase_data = cumsum(randn(N)) * 1e-9  # Random walk phase noise
tau0 = 1.0  # Sampling interval (seconds)

# Compute Allan deviation
result = adev(phase_data, tau0)
println("ADEV at τ=1s: ", result.deviation[1])

# Multiple return pattern
tau, dev = adev(phase_data, tau0, Val(2))
tau, dev, edf = adev(phase_data, tau0, Val(3))
```

### Advanced Usage

```julia
# Custom parameters
result = adev(phase_data, tau0, 
              mlist=[1, 2, 4, 8, 16], 
              confidence=0.95)

# Compare different deviation types
adev_result = adev(phase_data, tau0)
mdev_result = mdev(phase_data, tau0)
mhdev_result = mhdev(phase_data, tau0)

# Time-domain deviations (units: seconds)
tdev_result = tdev(phase_data, tau0)  # Time deviation
ldev_result = ldev(phase_data, tau0)  # Lapinski deviation
```

### Working with Results

```julia
result = adev(phase_data, tau0)

# Access all data
println("Averaging times: ", result.tau)
println("Deviation values: ", result.deviation)
println("Confidence intervals: ", result.ci)
println("Method: ", result.method)
println("Sample info: N=$(result.N), tau0=$(result.tau0)")

# Mathematical relationships verified
mdev_result = mdev(phase_data, tau0)
tdev_result = tdev(phase_data, tau0)

# TDEV = τ × MDEV / √3
expected = mdev_result.tau .* mdev_result.deviation ./ sqrt(3)
@assert tdev_result.deviation ≈ expected
```

## Mathematical Background

### Key Relationships
- **TDEV = τ × MDEV / √3** (time deviation from modified Allan)
- **LDEV = τ × MHDEV / √(10/3)** (Lapinski from modified Hadamard)

### Noise Types and Slopes
- **White PM** (α=2): 
  - ADEV slope ≈ -1.0, MDEV slope ≈ -1.5
  - TDEV slope ≈ 0.0, LDEV slope ≈ -0.5
- **Flicker PM** (α=1): 
  - ADEV slope ≈ -1.0, MDEV slope ≈ -1.0
  - TDEV slope ≈ 0.0, LDEV slope ≈ 0.0
- **White FM** (α=0): 
  - ADEV slope ≈ -0.5, MDEV slope ≈ -0.5
  - TDEV slope ≈ +0.5, LDEV slope ≈ +0.5
- **Flicker FM** (α=-1): 
  - ADEV slope ≈ 0.0, MDEV slope ≈ 0.0
  - TDEV slope ≈ +1.0, LDEV slope ≈ +1.0
- **Random Walk FM** (α=-2): 
  - ADEV slope ≈ +0.5, MDEV slope ≈ +0.5
  - TDEV slope ≈ +1.5, LDEV slope ≈ +1.5

*Note: Flicker noise types are more complex to generate synthetically and are not included in validation tests.*

### Data Requirements
- **Allan family**: `adev()`, `mdev()` need ≥2m, ≥3m points respectively
- **Hadamard family**: `mhdev()` needs ≥4m points
- **Phase data** in seconds with positive sampling interval `tau0`

## API Reference

### Core Functions

All deviation functions support the same API pattern:

```julia
# Single return (recommended)
result = deviation_function(phase_data, tau0; kwargs...)

# Multiple returns
tau, dev = deviation_function(phase_data, tau0, Val(2); kwargs...)
tau, dev, edf = deviation_function(phase_data, tau0, Val(3); kwargs...)
tau, dev, edf, ci = deviation_function(phase_data, tau0, Val(4); kwargs...)
tau, dev, edf, ci, alpha = deviation_function(phase_data, tau0, Val(5); kwargs...)
```

#### Parameters
- `phase_data`: Phase data vector (seconds)
- `tau0`: Sampling interval (seconds, positive)

#### Keyword Arguments
- `mlist`: Averaging factors (default: octave spacing)
- `confidence`: Confidence level (default: 0.683 for 68.3%)

#### Returns (DeviationResult)
- `tau`: Averaging times τ = m·τ₀ (seconds)
- `deviation`: Deviation values
- `edf`: Equivalent degrees of freedom
- `ci`: Confidence intervals [lower, upper]
- `alpha`: Noise type exponents
- `neff`: Effective number of samples
- `tau0`: Original sampling interval
- `N`: Original data length
- `method`: Function identifier
- `confidence`: Confidence level used

## Testing & Validation

StabLab.jl includes comprehensive tests validating:
- **Algorithm correctness** against theoretical noise slopes
- **Mathematical relationships** between deviation types
- **API functionality** across all return patterns
- **Edge cases** and error handling

Run tests:
```julia
# From package directory
julia test_slopes.jl    # Validate theoretical slopes
julia test_complete.jl  # Full functionality test
julia test_tdev_ldev.jl # Time deviation relationships
```

## References

- **W. J. Riley & D. A. Howe**, "Handbook of Frequency Stability Analysis," NIST Special Publication 1065
- **NIST SP1065**: https://www.nist.gov/publications/handbook-frequency-stability-analysis
- **IEEE Standards** for frequency stability characterization
- **Original MATLAB StabLab** for algorithm validation

## Contributing

StabLab.jl follows Julia best practices:
- Type-safe implementations with comprehensive validation
- Consistent API patterns across all functions
- Performance-optimized algorithms
- Comprehensive documentation and testing

## License

Provided as-is for frequency stability analysis. Users should validate results against their specific requirements and standards.

## Acknowledgments

Based on algorithms from NIST SP1065 and validated against MATLAB StabLab implementations. Developed as part of the masterclock-kflab project for oscillator control and analysis.