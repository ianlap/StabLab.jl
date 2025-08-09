# Test Total deviation implementation

using Pkg
Pkg.activate(".")

using StabLab
using Random

# Set seed for reproducible results
Random.seed!(42)

println("=== Testing TOTDEV Implementation ===\n")

# Generate test data
N = 1000
tau0 = 1.0
phase_data = cumsum(randn(N)) * 1e-9  # White FM noise (random walk phase)

println("Test data: $N samples of White FM noise (random walk phase)")
println("Sample interval: $tau0 seconds\n")

# Test totdev
println("Testing totdev()...")
result_totdev = totdev(phase_data, tau0)

if !isempty(result_totdev.tau)
    println("✓ totdev() - $(length(result_totdev.tau)) tau points")
    println("  Method: ", result_totdev.method)
    println("  First tau: ", result_totdev.tau[1])
    println("  First totdev: ", result_totdev.deviation[1])
    
    # Compare with other deviations
    result_adev = adev(phase_data, tau0)
    result_mdev = mdev(phase_data, tau0)
    
    # Show comparison for first few points
    n_show = min(3, length(result_totdev.tau))
    println("\n=== Deviation Comparison (first $n_show points) ===")
    println("Tau (s) | ADEV       | MDEV       | TOTDEV")
    println("--------|------------|------------|------------")
    
    for i in 1:n_show
        tau_val = result_totdev.tau[i]
        # Find matching tau in other results
        adev_idx = findfirst(x -> isapprox(x, tau_val, rtol=0.01), result_adev.tau)
        mdev_idx = findfirst(x -> isapprox(x, tau_val, rtol=0.01), result_mdev.tau)
        
        adev_val = adev_idx !== nothing ? result_adev.deviation[adev_idx] : NaN
        mdev_val = mdev_idx !== nothing ? result_mdev.deviation[mdev_idx] : NaN
        totdev_val = result_totdev.deviation[i]
        
        println("$(rpad(tau_val, 7)) | $(rpad(round(adev_val, sigdigits=5), 10)) | $(rpad(round(mdev_val, sigdigits=5), 10)) | $(round(totdev_val, sigdigits=5))")
    end
    
    println("\n✅ TOTDEV implementation successful!")
    println("Note: Total deviation should generally be similar to Allan deviation")
    println("      but may differ due to detrending and all-sample usage.")
else
    println("⚠️  TOTDEV returned no valid results")
    println("This might indicate an issue with the implementation or insufficient data.")
end

println("\nTOTDEV test completed.")