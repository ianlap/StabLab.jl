# Quick test of Modified Hadamard deviation

using Pkg
Pkg.activate(".")

using StabLab
using Random

# Generate test data
Random.seed!(42)
N = 1000
phase_data = cumsum(randn(N)) * 1e-9  # Random walk phase data
tau0 = 1.0

println("Testing Modified Hadamard deviation...")

# Test mhdev
result = mhdev(phase_data, tau0)
println("Method: ", result.method)
println("N points: ", result.N)
println("First tau: ", result.tau[1])
println("First mhdev: ", result.deviation[1])
println("Number of tau points: ", length(result.tau))

# Compare with other deviations
result_adev = adev(phase_data, tau0)
result_mdev = mdev(phase_data, tau0)

# Show first few values for comparison
n_compare = min(4, length(result.tau))
println("\nComparison (first $n_compare points):")
println("Tau   | ADEV      | MDEV      | MHDEV")
println("------|-----------|-----------|----------")
for i in 1:n_compare
    println("$(result.tau[i])   | $(round(result_adev.deviation[i], sigdigits=6)) | $(round(result_mdev.deviation[i], sigdigits=6)) | $(round(result.deviation[i], sigdigits=6))")
end

println("\nMHDEV test completed successfully!")