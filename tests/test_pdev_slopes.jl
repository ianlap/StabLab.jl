using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using StabLab
using Statistics
using Random
using Printf
using FFTW

println("Testing PDEV Theoretical Slopes")
println("="^50)

# Set random seed
Random.seed!(42)

# Test parameters
N = 100000
tau0 = 1.0

# Test 1: White Phase Noise (WPM)
println("\n1. White Phase Noise (α = 2)")
println("-"^30)
# Generate white phase noise
white_phase = cumsum(randn(N) * 1e-9)

# Compute PDEV and ADEV
pdev_result = pdev(white_phase, tau0)
adev_result = adev(white_phase, tau0)

# Calculate slopes over middle range
idx1, idx2 = 3, 10
if length(pdev_result.tau) >= idx2
    pdev_slope = (log10(pdev_result.deviation[idx2]) - log10(pdev_result.deviation[idx1])) / 
                 (log10(pdev_result.tau[idx2]) - log10(pdev_result.tau[idx1]))
    adev_slope = (log10(adev_result.deviation[idx2]) - log10(adev_result.deviation[idx1])) / 
                 (log10(adev_result.tau[idx2]) - log10(adev_result.tau[idx1]))
    
    println("Slopes (log-log):")
    println("  ADEV: $(@sprintf("%.3f", adev_slope)) (theory: -1.0)")
    println("  PDEV: $(@sprintf("%.3f", pdev_slope)) (theory: -1.5)")
    
    # Check m=1 case
    println("\nAt τ=1s:")
    println("  ADEV: $(@sprintf("%.6e", adev_result.deviation[1]))")
    println("  PDEV: $(@sprintf("%.6e", pdev_result.deviation[1]))")
    println("  Ratio: $(@sprintf("%.6f", pdev_result.deviation[1]/adev_result.deviation[1])) (should be 1.0)")
end

# Test 2: White Frequency Noise (WFM)
println("\n2. White Frequency Noise (α = 0)")
println("-"^30)
# Generate white frequency noise
freq_noise = randn(N) * 1e-12
phase_wfm = cumsum(freq_noise) * tau0

pdev_wfm = pdev(phase_wfm, tau0)
adev_wfm = adev(phase_wfm, tau0)

if length(pdev_wfm.tau) >= idx2
    pdev_slope = (log10(pdev_wfm.deviation[idx2]) - log10(pdev_wfm.deviation[idx1])) / 
                 (log10(pdev_wfm.tau[idx2]) - log10(pdev_wfm.tau[idx1]))
    adev_slope = (log10(adev_wfm.deviation[idx2]) - log10(adev_wfm.deviation[idx1])) / 
                 (log10(adev_wfm.tau[idx2]) - log10(adev_wfm.tau[idx1]))
    
    println("Slopes (log-log):")
    println("  ADEV: $(@sprintf("%.3f", adev_slope)) (theory: -0.5)")
    println("  PDEV: $(@sprintf("%.3f", pdev_slope)) (theory: -0.5)")
end

# Test 3: Flicker Frequency Noise (FFM)
println("\n3. Flicker Frequency Noise (α = -1)")
println("-"^30)
# Approximate flicker frequency noise (1/f)
freqs = fft(randn(N))
f = fftfreq(N, 1/tau0)
# Apply 1/f filter (avoiding DC)
for i in 2:div(N,2)
    freqs[i] *= 1/sqrt(abs(f[i]))
end
freq_ffm = real(ifft(freqs)) * 1e-13
phase_ffm = cumsum(freq_ffm) * tau0

pdev_ffm = pdev(phase_ffm, tau0)
adev_ffm = adev(phase_ffm, tau0)

if length(pdev_ffm.tau) >= idx2
    pdev_slope = (log10(pdev_ffm.deviation[idx2]) - log10(pdev_ffm.deviation[idx1])) / 
                 (log10(pdev_ffm.tau[idx2]) - log10(pdev_ffm.tau[idx1]))
    adev_slope = (log10(adev_ffm.deviation[idx2]) - log10(adev_ffm.deviation[idx1])) / 
                 (log10(adev_ffm.tau[idx2]) - log10(adev_ffm.tau[idx1]))
    
    println("Slopes (log-log):")
    println("  ADEV: $(@sprintf("%.3f", adev_slope)) (theory: 0.0)")
    println("  PDEV: $(@sprintf("%.3f", pdev_slope)) (theory: 0.0)")
end

# Test 4: Linear Drift Removal
println("\n4. Linear Drift Removal Test")
println("-"^30)
# Add strong linear drift
drift_rate = 1e-10  # 100 ps/s
t = (0:N-1) * tau0
phase_drift = white_phase + drift_rate * t

pdev_drift = pdev(phase_drift, tau0)
adev_drift = adev(phase_drift, tau0)

# Compare at large tau where drift dominates
if length(pdev_drift.tau) >= 15
    idx_large = 15
    pdev_improvement = pdev_drift.deviation[idx_large] / adev_drift.deviation[idx_large]
    println("At τ = $(pdev_drift.tau[idx_large])s:")
    println("  ADEV: $(@sprintf("%.3e", adev_drift.deviation[idx_large]))")
    println("  PDEV: $(@sprintf("%.3e", pdev_drift.deviation[idx_large]))")
    println("  PDEV/ADEV ratio: $(@sprintf("%.3f", pdev_improvement))")
    println("  PDEV shows $(pdev_improvement < 1 ? "better" : "worse") drift rejection")
end

# Test 5: Detailed m=1 verification
println("\n5. Detailed m=1 Verification")
println("-"^30)
# For m=1, PDEV should exactly equal ADEV
test_data = randn(1000) * 1e-9
pdev1 = pdev(test_data, tau0)
adev1 = adev(test_data, tau0)

# Both should have m=1 as first point
println("Random data test:")
println("  PDEV(m=1): $(@sprintf("%.9e", pdev1.deviation[1]))")
println("  ADEV(m=1): $(@sprintf("%.9e", adev1.deviation[1]))")
println("  Difference: $(@sprintf("%.3e", abs(pdev1.deviation[1] - adev1.deviation[1])))")

# Manual calculation for m=1
function manual_adev_calc(data, tau0)
    n = length(data) - 2
    sum_sq = 0.0
    for i in 1:n
        diff = data[i+2] - 2*data[i+1] + data[i]
        sum_sq += diff^2
    end
    return sqrt(sum_sq / (2 * n)) / tau0
end

manual_adev = manual_adev_calc(test_data, tau0)

println("\nManual ADEV calculation: $(@sprintf("%.9e", manual_adev))")
println("Matches ADEV function: $(abs(manual_adev - adev1.deviation[1]) < 1e-12 ? "YES" : "NO")")

println("\nPDEV Slope Analysis Complete!")

# Debug the NaN issue
println("\n6. Debug NaN Issues")
println("-"^30)
if any(isnan.(pdev_drift.deviation))
    nan_indices = findall(isnan, pdev_drift.deviation)
    println("PDEV NaN values at tau indices: $(nan_indices)")
    println("Corresponding tau values: $(pdev_drift.tau[nan_indices])")
    println("This indicates numerical instability in PDEV computation")
end