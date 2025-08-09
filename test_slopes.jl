# Test Allan and Modified Allan deviation slopes for different noise types

using Pkg
Pkg.activate(".")

using StabLab
using Random
using LinearAlgebra

# Set seed for reproducible results
Random.seed!(42)

println("=== StabLab Slope Validation Test ===\n")

# Generate test datasets
N = 10000
tau0 = 1.0

# Test 1: White phase noise (should give ADEV slope = -1, MDEV slope = -1.5)
println("Test 1: White Phase Noise (N=$N)")
white_phase = randn(N) * 1e-9  # Independent white noise samples
println("Generated white phase noise dataset")

result_adev_white = adev(white_phase, tau0)
result_mdev_white = mdev(white_phase, tau0)

# Calculate slopes in log-log space (using first several points)
n_points = min(6, length(result_adev_white.tau))
log_tau = log10.(result_adev_white.tau[1:n_points])
log_adev = log10.(result_adev_white.deviation[1:n_points])
log_mdev = log10.(result_mdev_white.deviation[1:n_points])

# Linear fit: log(dev) = slope * log(tau) + intercept
slope_adev_white = (log_adev[end] - log_adev[1]) / (log_tau[end] - log_tau[1])
slope_mdev_white = (log_mdev[end] - log_mdev[1]) / (log_tau[end] - log_tau[1])

println("  ADEV slope: $(round(slope_adev_white, digits=3)) (theoretical: -1.0)")
println("  MDEV slope: $(round(slope_mdev_white, digits=3)) (theoretical: -1.5)")

# Test 2: White FM noise (random walk phase, should give both ADEV and MDEV slope = -0.5)  
println("\nTest 2: White FM Noise (Random Walk Phase) (N=$N)")
random_walk_phase = cumsum(randn(N)) * 1e-9  # Cumulative sum = random walk phase = White FM
println("Generated White FM noise dataset (random walk phase)")

result_adev_rw = adev(random_walk_phase, tau0)
result_mdev_rw = mdev(random_walk_phase, tau0)

# Calculate slopes for random walk
log_tau_rw = log10.(result_adev_rw.tau[1:n_points])
log_adev_rw = log10.(result_adev_rw.deviation[1:n_points])
log_mdev_rw = log10.(result_mdev_rw.deviation[1:n_points])

slope_adev_rw = (log_adev_rw[end] - log_adev_rw[1]) / (log_tau_rw[end] - log_tau_rw[1])
slope_mdev_rw = (log_mdev_rw[end] - log_mdev_rw[1]) / (log_tau_rw[end] - log_tau_rw[1])

println("  ADEV slope: $(round(slope_adev_rw, digits=3)) (theoretical: -0.5)")
println("  MDEV slope: $(round(slope_mdev_rw, digits=3)) (theoretical: -0.5)")

# Test 3: Random Walk FM noise (double integration, should give slopes = +0.5)
println("\nTest 3: Random Walk FM Noise (Double Integration) (N=$N)")
rwfm_phase = cumsum(cumsum(randn(N))) * 1e-9  # Double integration = RWFM
println("Generated RWFM noise dataset (double integration)")

result_adev_rwfm = adev(rwfm_phase, tau0)
result_mdev_rwfm = mdev(rwfm_phase, tau0)

# Calculate slopes for RWFM
log_tau_rwfm = log10.(result_adev_rwfm.tau[1:n_points])
log_adev_rwfm = log10.(result_adev_rwfm.deviation[1:n_points])
log_mdev_rwfm = log10.(result_mdev_rwfm.deviation[1:n_points])

slope_adev_rwfm = (log_adev_rwfm[end] - log_adev_rwfm[1]) / (log_tau_rwfm[end] - log_tau_rwfm[1])
slope_mdev_rwfm = (log_mdev_rwfm[end] - log_mdev_rwfm[1]) / (log_tau_rwfm[end] - log_tau_rwfm[1])

println("  ADEV slope: $(round(slope_adev_rwfm, digits=3)) (theoretical: +0.5)")
println("  MDEV slope: $(round(slope_mdev_rwfm, digits=3)) (theoretical: +0.5)")

# Test 4: TDEV and LDEV slopes (should be +1 from MDEV/MHDEV due to τ multiplication)
println("\nTest 4: Time-Domain Deviation Slopes (τ scaling effect)")
println("Testing TDEV and LDEV slopes for White FM noise...")

result_tdev_wfm = tdev(random_walk_phase, tau0)
result_ldev_wfm = ldev(random_walk_phase, tau0)

# Calculate TDEV/LDEV slopes for White FM
log_tau_tdev = log10.(result_tdev_wfm.tau[1:n_points])
log_tdev = log10.(result_tdev_wfm.deviation[1:n_points])
log_ldev = log10.(result_ldev_wfm.deviation[1:n_points])

slope_tdev = (log_tdev[end] - log_tdev[1]) / (log_tau_tdev[end] - log_tau_tdev[1])
slope_ldev = (log_ldev[end] - log_ldev[1]) / (log_tau_tdev[end] - log_tau_tdev[1])

println("  TDEV slope: $(round(slope_tdev, digits=3)) (theoretical: +0.5, MDEV+1)")
println("  LDEV slope: $(round(slope_ldev, digits=3)) (theoretical: +0.5, MHDEV+1)")

# Summary and validation
println("\n=== Validation Summary ===")
println("Test Case                | Measure | Actual | Theoretical | Status")
println("-------------------------|---------|--------|-------------|--------")

# White phase noise validation
adev_white_ok = abs(slope_adev_white - (-1.0)) < 0.2
mdev_white_ok = abs(slope_mdev_white - (-1.5)) < 0.3
println("White Phase Noise        | ADEV    | $(rpad(round(slope_adev_white, digits=3), 6)) | -1.0        | $(adev_white_ok ? "✓ PASS" : "✗ FAIL")")
println("White Phase Noise        | MDEV    | $(rpad(round(slope_mdev_white, digits=3), 6)) | -1.5        | $(mdev_white_ok ? "✓ PASS" : "✗ FAIL")")

# White FM (random walk phase) validation  
adev_rw_ok = abs(slope_adev_rw - (-0.5)) < 0.2
mdev_rw_ok = abs(slope_mdev_rw - (-0.5)) < 0.2
println("White FM Noise           | ADEV    | $(rpad(round(slope_adev_rw, digits=3), 6)) | -0.5        | $(adev_rw_ok ? "✓ PASS" : "✗ FAIL")")
println("White FM Noise           | MDEV    | $(rpad(round(slope_mdev_rw, digits=3), 6)) | -0.5        | $(mdev_rw_ok ? "✓ PASS" : "✗ FAIL")")

# RWFM validation
adev_rwfm_ok = abs(slope_adev_rwfm - 0.5) < 0.2
mdev_rwfm_ok = abs(slope_mdev_rwfm - 0.5) < 0.2
println("Random Walk FM           | ADEV    | $(rpad(round(slope_adev_rwfm, digits=3), 6)) | +0.5        | $(adev_rwfm_ok ? "✓ PASS" : "✗ FAIL")")
println("Random Walk FM           | MDEV    | $(rpad(round(slope_mdev_rwfm, digits=3), 6)) | +0.5        | $(mdev_rwfm_ok ? "✓ PASS" : "✗ FAIL")")

# TDEV/LDEV validation (should be +0.5 for White FM)
tdev_ok = abs(slope_tdev - 0.5) < 0.3
ldev_ok = abs(slope_ldev - 0.5) < 0.3
println("White FM Noise           | TDEV    | $(rpad(round(slope_tdev, digits=3), 6)) | +0.5        | $(tdev_ok ? "✓ PASS" : "✗ FAIL")")
println("White FM Noise           | LDEV    | $(rpad(round(slope_ldev, digits=3), 6)) | +0.5        | $(ldev_ok ? "✓ PASS" : "✗ FAIL")")

all_pass = adev_white_ok && mdev_white_ok && adev_rw_ok && mdev_rw_ok && adev_rwfm_ok && mdev_rwfm_ok && tdev_ok && ldev_ok
println("\nOverall Test Result: $(all_pass ? "✓ ALL TESTS PASSED" : "✗ SOME TESTS FAILED")")

if all_pass
    println("🎉 StabLab algorithms correctly implemented!")
else
    println("⚠️  Check algorithm implementation - slopes don't match theory")
end