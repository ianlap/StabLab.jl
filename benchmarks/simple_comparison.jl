# Simple comparison test between implementations
using Pkg
Pkg.activate(".")

using StabLab
using Random

println("StabLab.jl Validation & Performance Test")
println("=" ^ 50)

# Generate consistent test data
Random.seed!(42)
N = 500000  # 500k samples - substantial but manageable
tau0 = 1.0
phase_data = cumsum(randn(N)) * 1e-9  # White FM noise

println("Test data: $N samples of White FM noise")
min_val = minimum(phase_data)
max_val = maximum(phase_data)
println("Data range: [$min_val, $max_val]")
println("Sample interval: $tau0 seconds\n")

# Test functions with timing
functions_to_test = [
    ("adev", adev),
    ("mdev", mdev),
    ("hdev", hdev)
]

results = Dict{String, Any}()

println("=== StabLab.jl Performance Test ===")
global total_time = 0.0

for (name, func) in functions_to_test
    print("Testing $name with $N samples... ")
    
    start_time = time()
    try
        result = func(phase_data, tau0)
        elapsed = time() - start_time
        global total_time += elapsed
        
        results[name] = result
        println("✓ $(length(result.tau)) points in $(round(elapsed, digits=3))s")
        println("  First value: $(result.deviation[1]:.6e)")
        
    catch e
        println("❌ Failed: $e")
    end
end

println("\nTotal computation time: $(round(total_time, digits=3))s")

# Show comparison table
if length(results) >= 3
    println("\n=== Results Comparison (first 5 tau values) ===")
    
    # Use ADEV tau values as reference
    ref_tau = results["adev"].tau
    n_show = min(5, length(ref_tau))
    
    println("Tau (s)     | ADEV         | MDEV         | HDEV")
    println("------------|--------------|--------------|------------")
    
    for i in 1:n_show
        tau_val = ref_tau[i]
        adev_val = results["adev"].deviation[i]
        
        # Find corresponding values in other results
        mdev_idx = findfirst(x -> isapprox(x, tau_val, rtol=0.01), results["mdev"].tau)
        hdev_idx = findfirst(x -> isapprox(x, tau_val, rtol=0.01), results["hdev"].tau)
        
        mdev_val = mdev_idx !== nothing ? results["mdev"].deviation[mdev_idx] : NaN
        hdev_val = hdev_idx !== nothing ? results["hdev"].deviation[hdev_idx] : NaN
        
        println("$(rpad(round(tau_val, digits=1), 11)) | $(rpad(round(adev_val, sigdigits=6), 12)) | $(rpad(round(mdev_val, sigdigits=6), 12)) | $(round(hdev_val, sigdigits=6))")
    end
end

# Performance metrics
println("\n=== Performance Metrics ===")
println("Dataset size: $N samples ($(round(N * 8 / 1024^2, digits=1)) MB)")
println("Total time: $(round(total_time, digits=3))s")
println("Throughput: $(round(N * length(functions_to_test) / total_time / 1e6, digits=2)) Msamples/sec")

println("\n🚀 StabLab.jl is ready for large-scale frequency stability analysis!")

# Save results as text file for manual comparison
open("/tmp/stablab_results.txt", "w") do io
    println(io, "StabLab.jl Results")
    println(io, "Data: $N samples, tau0 = $tau0")
    println(io, "Seed: 42")
    println(io, "")
    
    for (name, result) in results
        println(io, "$name:")
        for i in 1:min(10, length(result.tau))
            println(io, "  tau=$(result.tau[i]): $(result.deviation[i])")
        end
        println(io, "")
    end
end

println("Results saved to /tmp/stablab_results.txt for manual comparison")