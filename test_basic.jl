# Quick test of basic Allan deviation

using Pkg
Pkg.activate(".")

using StabLab
using Random

# Generate some simple test data
Random.seed!(42)
N = 1000
phase_data = cumsum(randn(N)) * 1e-9  # Random walk phase data
tau0 = 1.0

println("Testing Allan deviation...")

# Test single return (struct)
result = adev(phase_data, tau0)
println("Struct return:")
println("  Method: ", result.method)
println("  N points: ", result.N)
println("  First tau: ", result.tau[1])
println("  First adev: ", result.deviation[1])

# Test multiple return
tau, dev = adev(phase_data, tau0, Val(2))
println("\nMultiple return:")
println("  First tau: ", tau[1])
println("  First adev: ", dev[1])

# Test custom mlist
result2 = adev(phase_data, tau0, mlist=[1, 2, 4])
println("\nCustom mlist:")
println("  Tau values: ", result2.tau)
println("  Dev values: ", result2.deviation[1:3])

# Test modified Allan deviation
result_mdev = mdev(phase_data, tau0)
println("\nModified Allan deviation:")
println("  Method: ", result_mdev.method)
println("  First tau: ", result_mdev.tau[1])
println("  First mdev: ", result_mdev.deviation[1])

# Compare first few values
println("\nComparison (first 3 points):")
println("  Tau    | ADEV        | MDEV")
println("  -------|-------------|-------------")
for i in 1:min(3, length(result.tau))
    println("  $(result.tau[i])    | $(result.deviation[i]) | $(result_mdev.deviation[i])")
end

println("\nBasic test completed successfully!")