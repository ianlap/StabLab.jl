# Simple benchmark test to check our functions work
using Pkg
Pkg.activate(".")

using StabLab
using Random

# Generate test data
Random.seed!(42)
N = 10000  # Smaller dataset for testing
tau0 = 1.0
phase_data = cumsum(randn(N)) * 1e-9

println("Testing StabLab.jl functions with $N samples...")

# Test our functions
try
    println("Testing ADEV...")
    result_adev = adev(phase_data, tau0)
    println("✓ ADEV: $(length(result_adev.tau)) points")
    
    println("Testing MDEV...")
    result_mdev = mdev(phase_data, tau0)
    println("✓ MDEV: $(length(result_mdev.tau)) points")
    
    println("Testing HDEV...")
    result_hdev = hdev(phase_data, tau0)
    println("✓ HDEV: $(length(result_hdev.tau)) points")
    
    println("\n🎉 All functions working correctly!")
    
catch e
    println("❌ Error: $e")
    println("Stack trace:")
    for (exc, bt) in Base.catch_stack()
        showerror(stdout, exc, bt)
        println()
    end
end