# Test Modified Hadamard Total deviation implementation

using Pkg
Pkg.activate(".")

using StabLab
using Random

# Set seed for reproducible results
Random.seed!(42)

println("=== Testing MHTOTDEV Implementation ===\n")

# Generate test data - smaller N due to computational complexity
N = 200  # Small for testing
tau0 = 1.0
phase_data = cumsum(randn(N)) * 1e-9  # White FM noise (random walk phase)

println("Test data: $N samples of White FM noise (random walk phase)")
println("Sample interval: $tau0 seconds")
println("Note: Using small N=$N for quick testing of MHTOTDEV\n")

# Test mhtotdev
println("Testing mhtotdev()...")
try
    result_mhtotdev = mhtotdev(phase_data, tau0)

    if !isempty(result_mhtotdev.tau)
        println("✓ mhtotdev() - $(length(result_mhtotdev.tau)) tau points")
        println("  Method: ", result_mhtotdev.method)
        println("  First tau: ", result_mhtotdev.tau[1])
        println("  First mhtotdev: ", result_mhtotdev.deviation[1])
        
        # Compare with other Hadamard-family deviations
        result_mhdev = mhdev(phase_data, tau0)
        result_hdev = hdev(phase_data, tau0)
        
        # Show comparison for first few points
        n_show = min(3, length(result_mhtotdev.tau))
        println("\n=== Hadamard Family Comparison (first $n_show points) ===")
        println("Tau (s) | MHTOTDEV   | MHDEV      | HDEV")
        println("--------|------------|------------|------------")
        
        for i in 1:n_show
            tau_val = result_mhtotdev.tau[i]
            # Find matching tau values
            mhdev_idx = findfirst(x -> isapprox(x, tau_val, rtol=0.01), result_mhdev.tau)
            hdev_idx = findfirst(x -> isapprox(x, tau_val, rtol=0.01), result_hdev.tau)
            
            mhtotdev_val = result_mhtotdev.deviation[i]
            mhdev_val = mhdev_idx !== nothing ? result_mhdev.deviation[mhdev_idx] : NaN
            hdev_val = hdev_idx !== nothing ? result_hdev.deviation[hdev_idx] : NaN
            
            println("$(rpad(tau_val, 7)) | $(rpad(round(mhtotdev_val, sigdigits=5), 10)) | $(rpad(round(mhdev_val, sigdigits=5), 10)) | $(round(hdev_val, sigdigits=5))")
        end
        
        # Test multiple return patterns
        tau, dev = mhtotdev(phase_data, tau0, Val(2))
        println("\n✓ Multiple return pattern works")
        println("  Returned $(length(tau)) tau values")
        
        println("\n✅ MHTOTDEV implementation successful!")
        println("Note: Modified Hadamard Total deviation combines the robustness")
        println("      of Hadamard deviations with total deviation's all-sample usage.")
        println("      EDF values are NaN as no published EDF model is available.")
    else
        println("⚠️  MHTOTDEV returned no valid results")
        println("This might indicate an issue with the implementation or insufficient data.")
    end
catch e
    println("❌ Error in MHTOTDEV: ", e)
end

println("\nMHTOTDEV test completed.")