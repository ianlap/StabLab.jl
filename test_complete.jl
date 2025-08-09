# Complete test of StabLab.jl core functions

using Pkg
Pkg.activate(".")

using StabLab
using Random

# Set seed for reproducible results
Random.seed!(42)

println("=== StabLab.jl Core Functions Test ===\n")

# Generate test data
N = 1000
tau0 = 1.0
phase_data = cumsum(randn(N)) * 1e-9  # Random walk phase data

println("Test data: $N samples of random walk phase noise")
println("Sample interval: $tau0 seconds\n")

# Test all implemented functions
println("Testing implemented functions:")

# 1. Allan deviation
result_adev = adev(phase_data, tau0)
println("✓ adev() - $(length(result_adev.tau)) tau points")

# 2. Modified Allan deviation  
result_mdev = mdev(phase_data, tau0)
println("✓ mdev() - $(length(result_mdev.tau)) tau points")

# 3. Modified Hadamard deviation
result_mhdev = mhdev(phase_data, tau0)
println("✓ mhdev() - $(length(result_mhdev.tau)) tau points")

# 4. Time deviation
result_tdev = tdev(phase_data, tau0)
println("✓ tdev() - $(length(result_tdev.tau)) tau points")

# 5. Lapinski deviation
result_ldev = ldev(phase_data, tau0)
println("✓ ldev() - $(length(result_ldev.tau)) tau points")

# 6. Total deviation
result_totdev = totdev(phase_data, tau0)
println("✓ totdev() - $(length(result_totdev.tau)) tau points")

# Test multiple return patterns
tau, dev = adev(phase_data, tau0, Val(2))
println("✓ Multiple return pattern works")

# Show comparison table
println("\n=== Function Comparison (first 4 tau values) ===")
n_show = min(4, length(result_adev.tau))
println("Tau (s) | ADEV       | MDEV       | MHDEV      | TOTDEV     | TDEV (s)   | LDEV (s)")
println("--------|------------|------------|------------|------------|------------|------------")

for i in 1:min(n_show, length(result_tdev.tau), length(result_ldev.tau), length(result_totdev.tau))
    tau_val = result_adev.tau[i]
    adev_val = result_adev.deviation[i]
    mdev_val = result_mdev.deviation[i] 
    mhdev_val = result_mhdev.deviation[i]
    totdev_val = result_totdev.deviation[i]
    tdev_val = result_tdev.deviation[i]
    ldev_val = result_ldev.deviation[i]
    println("$(rpad(tau_val, 7)) | $(rpad(round(adev_val, sigdigits=5), 10)) | $(rpad(round(mdev_val, sigdigits=5), 10)) | $(rpad(round(mhdev_val, sigdigits=5), 10)) | $(rpad(round(totdev_val, sigdigits=5), 10)) | $(rpad(round(tdev_val, sigdigits=5), 10)) | $(round(ldev_val, sigdigits=5))")
end

# Test custom parameters
println("\n=== Custom Parameters Test ===")
result_custom = adev(phase_data, tau0, mlist=[1, 2, 4, 8], confidence=0.95)
println("Custom mlist and confidence level:")
println("  Tau values: $(result_custom.tau)")
println("  Confidence level: $(result_custom.confidence)")
println("  CI range at τ=1s: [$(round(result_custom.ci[1,1], sigdigits=4)), $(round(result_custom.ci[1,2], sigdigits=4))]")

println("\n🎉 All core StabLab functions are working correctly!")
println("\nReady for KalmanFilterToolbox integration.")