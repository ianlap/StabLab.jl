# Test Hadamard deviation implementation

using Pkg
Pkg.activate(".")

using StabLab
using Random

# Set seed for reproducible results
Random.seed!(42)

println("=== Testing HDEV Implementation ===\n")

# Generate test data
N = 1000
tau0 = 1.0
phase_data = cumsum(randn(N)) * 1e-9  # White FM noise (random walk phase)

println("Test data: $N samples of White FM noise (random walk phase)")
println("Sample interval: $tau0 seconds\n")

# Test hdev
println("Testing hdev()...")
result_hdev = hdev(phase_data, tau0)

if !isempty(result_hdev.tau)
    println("✓ hdev() - $(length(result_hdev.tau)) tau points")
    println("  Method: ", result_hdev.method)
    println("  First tau: ", result_hdev.tau[1])
    println("  First hdev: ", result_hdev.deviation[1])
    
    # Compare with other Hadamard-family deviations
    result_mhdev = mhdev(phase_data, tau0)
    
    # Show comparison for first few points
    n_show = min(3, length(result_hdev.tau))
    println("\n=== Hadamard Family Comparison (first $n_show points) ===")
    println("Tau (s) | HDEV       | MHDEV")
    println("--------|------------|------------")
    
    for i in 1:n_show
        tau_val = result_hdev.tau[i]
        # Find matching tau in MHDEV results
        mhdev_idx = findfirst(x -> isapprox(x, tau_val, rtol=0.01), result_mhdev.tau)
        
        hdev_val = result_hdev.deviation[i]
        mhdev_val = mhdev_idx !== nothing ? result_mhdev.deviation[mhdev_idx] : NaN
        
        println("$(rpad(tau_val, 7)) | $(rpad(round(hdev_val, sigdigits=5), 10)) | $(round(mhdev_val, sigdigits=5))")
    end
    
    # Test multiple return patterns
    tau, dev = hdev(phase_data, tau0, Val(2))
    println("\n✓ Multiple return pattern works")
    println("  Returned $(length(tau)) tau values")
    
    println("\n✅ HDEV implementation successful!")
    println("Note: Hadamard deviations are robust against linear frequency drift")
    println("      and use third differences for stability analysis.")
else
    println("⚠️  HDEV returned no valid results")
    println("This might indicate an issue with the implementation or insufficient data.")
end

println("\nHDEV test completed.")