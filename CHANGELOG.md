# Changelog

All notable changes to StabLab.jl will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2025-08-09

### Added
- **Time deviation (`tdev`)**: Compute time deviation using TDEV = τ × MDEV / √3 relationship
- **Lapinski deviation (`ldev`)**: Compute Lapinski deviation using LDEV = τ × MHDEV / √(10/3) relationship
- **Total deviation (`totdev`)**: Uses all overlapping samples with detrending and symmetric reflection
- Comprehensive mathematical relationship validation in tests
- Enhanced test suite with theoretical slope validation for all deviation types
- Proper units handling (time deviations return seconds, frequency deviations are dimensionless)

### Changed
- Enhanced `DeviationResult` struct to support all deviation types consistently
- Improved test coverage with dedicated tests for TDEV/LDEV mathematical relationships
- Updated exports to include `tdev`, `ldev`, and `totdev` functions

### Technical Details
- TDEV and LDEV implementations efficiently reuse existing MDEV and MHDEV calculations
- All mathematical relationships verified: TDEV/MDEV ratio ≈ 0.577 at τ=1s, LDEV/MHDEV ratio ≈ 0.548 at τ=1s
- Confidence intervals properly scaled according to mathematical transformations

## [0.1.0] - 2025-08-09

### Added
- **Core package structure** with modern Julia architecture
- **Allan deviation (`adev`)**: Fundamental frequency stability measure with exact MATLAB algorithm translation
- **Modified Allan deviation (`mdev`)**: Removes dead time effects using triple-difference algorithm  
- **Modified Hadamard deviation (`mhdev`)**: Robust against frequency drift using third differences
- **Flexible API design** supporting both struct returns and multiple output patterns
- **Type-safe data structures** with `DeviationResult{T}` for comprehensive results
- **Comprehensive input validation** for phase data and sampling intervals
- **Keyword argument support** for custom averaging factors (`mlist`) and confidence levels
- **Theoretical validation** against expected noise slopes:
  - White phase noise: ADEV slope ≈ -1.0, MDEV slope ≈ -1.5 ✓
  - Random walk phase: Both ADEV and MDEV slope ≈ -0.5 ✓

### Implementation Highlights
- **Exact indexing translation** from MATLAB with careful attention to algorithm correctness
- **Efficient cumulative sum approach** for Modified Hadamard deviation computation
- **Octave-spaced default averaging factors** with appropriate minimum point requirements
- **Placeholder implementations** for noise identification and confidence interval computation
- **Multiple dispatch support** for different return patterns using `Val` types

### Testing
- Comprehensive slope validation against theoretical values for different noise types
- Algorithm correctness verification using 10,000 sample datasets
- Mathematical relationship testing between deviation types
- Edge case and error condition testing

### Dependencies
- Julia ≥ 1.6
- Statistics.jl (standard library)

### Initial Features
- Clean, consistent API across all deviation functions
- Type-safe implementations with comprehensive validation
- Performance-optimized algorithms following Julia best practices
- Extensive documentation with mathematical background and usage examples

---

## Development Notes

### Version Strategy
- **0.1.x**: Core Allan variance family (adev, mdev, mhdev)
- **0.2.x**: Time-domain deviations (tdev, ldev)
- **0.3.x**: Planned - Total deviation family (totdev, mtotdev, htotdev, mhtotdev)
- **0.4.x**: Planned - Enhanced confidence intervals and noise identification
- **0.5.x**: Planned - Plotting and visualization support
- **1.0.0**: Planned - Feature complete with comprehensive test suite and documentation

### Algorithm Validation
All implementations are validated against:
- MATLAB StabLab reference implementations
- NIST SP1065 specifications  
- Theoretical noise model expectations
- IEEE frequency stability standards