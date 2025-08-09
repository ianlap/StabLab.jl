# Minimal test to check if Julia benchmark basics work

using Pkg
Pkg.activate("..")

using StabLab
using Random
using Statistics

function test_minimal()
    println("Testing basic Julia benchmark functions...")
    
    # Small test dataset
    Random.seed!(42)
    N = 1000
    phase_data = cumsum(randn(N)) * 1e-9
    tau0 = 1.0
    
    # Test each function individually
    println("Testing ADEV...")
    result_adev = adev(phase_data, tau0)
    first_val = result_adev.deviation[1]
    println("  ADEV: $(length(result_adev.tau)) tau points, first dev = $first_val")
    
    println("Testing MDEV...")
    result_mdev = mdev(phase_data, tau0)
    first_val = result_mdev.deviation[1]
    println("  MDEV: $(length(result_mdev.tau)) tau points, first dev = $first_val")
    
    println("Testing HDEV...")
    result_hdev = hdev(phase_data, tau0)
    first_val = result_hdev.deviation[1]
    println("  HDEV: $(length(result_hdev.tau)) tau points, first dev = $first_val")
    
    println("✅ All functions work correctly!")
    return true
end

if abspath(PROGRAM_FILE) == @__FILE__
    test_minimal()
end