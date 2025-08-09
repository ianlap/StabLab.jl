# Test Modified Total deviation implementation

using Pkg
Pkg.activate(".")

using StabLab
using Random

# Set seed for reproducible results
Random.seed!(42)

println("=== Testing MTOTDEV Implementation ===\n")

# Generate test data - smaller N due to computational complexity
N = 500  # Reduced for faster testing
tau0 = 1.0
phase_data = cumsum(randn(N)) * 1e-9  # White FM noise (random walk phase)

println("Test data: $N samples of White FM noise (random walk phase)")
println("Sample interval: $tau0 seconds")
println("Note: Using smaller N=$N due to computational complexity of MTOTDEV\n")

# Test mtotdev
println("Testing mtotdev()...")
result_mtotdev = mtotdev(phase_data, tau0)

if !isempty(result_mtotdev.tau)
    println("✓ mtotdev() - $(length(result_mtotdev.tau)) tau points")
    println("  Method: ", result_mtotdev.method)
    println("  First tau: ", result_mtotdev.tau[1])
    println("  First mtotdev: ", result_mtotdev.deviation[1])
    
    # Compare with other total deviation types  
    result_totdev = totdev(phase_data, tau0)
    
    # Show comparison for first few points
    n_show = min(3, length(result_mtotdev.tau))
    println("\n=== Total Deviation Family Comparison (first $n_show points) ===")
    println("Tau (s) | MTOTDEV    | TOTDEV")
    println("--------|------------|------------")
    
    for i in 1:n_show
        tau_val = result_mtotdev.tau[i]
        # Find matching tau in TOTDEV results
        totdev_idx = findfirst(x -> isapprox(x, tau_val, rtol=0.01), result_totdev.tau)
        
        mtotdev_val = result_mtotdev.deviation[i]
        totdev_val = totdev_idx !== nothing ? result_totdev.deviation[totdev_idx] : NaN
        
        println("$(rpad(tau_val, 7)) | $(rpad(round(mtotdev_val, sigdigits=5), 10)) | $(round(totdev_val, sigdigits=5))")
    end
    
    # Test multiple return patterns
    tau, dev = mtotdev(phase_data, tau0, Val(2))
    println("\n✓ Multiple return pattern works")
    println("  Returned $(length(tau)) tau values")
    
    println("\n✅ MTOTDEV implementation successful!")
    println("Note: Modified Total deviation uses half-average detrending")
    println("      and uninverted even reflection for better stability analysis.")
else
    println("⚠️  MTOTDEV returned no valid results")
    println("This might indicate an issue with the implementation or insufficient data.")
end

println("\nMTOTDEV test completed.")