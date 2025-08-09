# Test Hadamard Total deviation implementation

using Pkg
Pkg.activate(".")

using StabLab
using Random

# Set seed for reproducible results
Random.seed!(42)

println("=== Testing HTOTDEV Implementation ===\n")

# Generate test data - smaller N due to computational complexity
N = 200  # Very small for testing
tau0 = 1.0
phase_data = cumsum(randn(N)) * 1e-9  # White FM noise (random walk phase)

println("Test data: $N samples of White FM noise (random walk phase)")
println("Sample interval: $tau0 seconds")
println("Note: Using very small N=$N for quick testing of HTOTDEV\n")

# Test htotdev
println("Testing htotdev()...")
try
    result_htotdev = htotdev(phase_data, tau0)

    if !isempty(result_htotdev.tau)
        println("✓ htotdev() - $(length(result_htotdev.tau)) tau points")
        println("  Method: ", result_htotdev.method)
        println("  First tau: ", result_htotdev.tau[1])
        println("  First htotdev: ", result_htotdev.deviation[1])
        
        # Show results
        n_show = min(3, length(result_htotdev.tau))
        println("\n=== HTOTDEV Results (first $n_show points) ===")
        println("Tau (s) | HTOTDEV")
        println("--------|------------")
        
        for i in 1:n_show
            tau_val = result_htotdev.tau[i]
            htotdev_val = result_htotdev.deviation[i]
            println("$(rpad(tau_val, 7)) | $(round(htotdev_val, sigdigits=5))")
        end
        
        println("\n✅ HTOTDEV implementation successful!")
    else
        println("⚠️  HTOTDEV returned no valid results")
    end
catch e
    println("❌ Error in HTOTDEV: ", e)
end

println("\nHTOTDEV test completed.")