# Test Time deviation and Lapinski deviation

using Pkg
Pkg.activate(".")

using StabLab
using Random

# Set seed for reproducible results
Random.seed!(42)

println("=== Testing TDEV and LDEV ===\n")

# Generate test data
N = 1000
tau0 = 1.0
phase_data = cumsum(randn(N)) * 1e-9  # Random walk phase data

println("Test data: $N samples of random walk phase noise")
println("Sample interval: $tau0 seconds\n")

# Test all implemented functions
result_mdev = mdev(phase_data, tau0)
result_mhdev = mhdev(phase_data, tau0)
result_tdev = tdev(phase_data, tau0)
result_ldev = ldev(phase_data, tau0)

println("Function tests:")
println("✓ tdev() - $(length(result_tdev.tau)) tau points")
println("✓ ldev() - $(length(result_ldev.tau)) tau points")

# Verify the mathematical relationships
println("\n=== Verifying Mathematical Relationships ===")

# TDEV = tau * MDEV / sqrt(3)
expected_tdev = result_mdev.tau .* result_mdev.deviation ./ sqrt(3)
tdev_match = isapprox(result_tdev.deviation, expected_tdev, rtol=1e-10)
println("TDEV = τ·MDEV/√3: $(tdev_match ? "✓ CORRECT" : "✗ ERROR")")

# LDEV = tau * MHDEV / sqrt(10/3)  
expected_ldev = result_mhdev.tau .* result_mhdev.deviation ./ sqrt(10/3)
ldev_match = isapprox(result_ldev.deviation, expected_ldev, rtol=1e-10)
println("LDEV = τ·MHDEV/√(10/3): $(ldev_match ? "✓ CORRECT" : "✗ ERROR")")

# Show comparison table
println("\n=== Deviation Comparison (first 4 tau values) ===")
n_show = min(4, length(result_mdev.tau))
println("Tau (s) | MDEV        | MHDEV       | TDEV (s)    | LDEV (s)")
println("--------|-------------|-------------|-------------|-------------")

for i in 1:n_show
    tau_val = result_mdev.tau[i]
    mdev_val = result_mdev.deviation[i]
    mhdev_val = result_mhdev.deviation[i] 
    tdev_val = result_tdev.deviation[i]
    ldev_val = result_ldev.deviation[i]
    println("$(rpad(tau_val, 7)) | $(rpad(round(mdev_val, sigdigits=5), 11)) | $(rpad(round(mhdev_val, sigdigits=5), 11)) | $(rpad(round(tdev_val, sigdigits=5), 11)) | $(round(ldev_val, sigdigits=5))")
end

println("\n=== Units Check ===")
println("Note: TDEV and LDEV have units of seconds (time deviations)")
println("      ADEV, MDEV, MHDEV are dimensionless (frequency deviations)")
println("      TDEV and LDEV should be much larger numerically due to τ scaling")

# Check that scaling factors are applied correctly (τ/√3 and τ/√(10/3))
# For tau=1: TDEV should be MDEV/√3 ≈ MDEV*0.577
# For tau=1: LDEV should be MHDEV/√(10/3) ≈ MHDEV*0.548
tdev_ratio_tau1 = result_tdev.deviation[1] / result_mdev.deviation[1]
ldev_ratio_tau1 = result_ldev.deviation[1] / result_mhdev.deviation[1]
expected_tdev_ratio = 1.0 / sqrt(3)  # ≈ 0.577
expected_ldev_ratio = 1.0 / sqrt(10/3)  # ≈ 0.548

tdev_ratio_ok = isapprox(tdev_ratio_tau1, expected_tdev_ratio, rtol=0.01)
ldev_ratio_ok = isapprox(ldev_ratio_tau1, expected_ldev_ratio, rtol=0.01)
println("TDEV/MDEV at τ=1: $(round(tdev_ratio_tau1, digits=3)) (expected: $(round(expected_tdev_ratio, digits=3))) $(tdev_ratio_ok ? "✓" : "✗")")
println("LDEV/MHDEV at τ=1: $(round(ldev_ratio_tau1, digits=3)) (expected: $(round(expected_ldev_ratio, digits=3))) $(ldev_ratio_ok ? "✓" : "✗")")

if tdev_match && ldev_match && tdev_ratio_ok && ldev_ratio_ok
    println("\n🎉 All TDEV and LDEV tests passed!")
else
    println("\n⚠️  Some tests failed - check implementation")
end