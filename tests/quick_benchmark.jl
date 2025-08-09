# Quick benchmark for oadev, mdev, ohdev with CI

using Pkg
Pkg.activate("..")
using StabLab, Random, Statistics

println("🚀 QUICK BENCHMARK: StabLab.jl with EDF/CI")
println("Functions: OADEV, MDEV, OHDEV")
println("Data: 5 datasets × 100k samples")

# Generate test data
Random.seed!(42)
N = 100_000
datasets = [cumsum(randn(N)) * 1e-9 for i in 1:5]
tau0 = 1.0

# Test functions
functions = [(adev, "OADEV"), (mdev, "MDEV"), (hdev, "OHDEV")]

for (func, name) in functions
    println("\n=== $name ===")
    times = Float64[]
    
    for (i, data) in enumerate(datasets)
        start = time()
        result = func(data, tau0)
        result_ci = compute_ci(result, 0.683)
        elapsed = time() - start
        
        push!(times, elapsed)
        
        println("  Dataset $i: $(round(elapsed, digits=3))s " *
               "(dev=$(round(result.deviation[1]*1e9, digits=1))ns, " *
               "edf=$(round(result_ci.edf[1], digits=0)))")
    end
    
    println("  Mean: $(round(mean(times), digits=3))s")
    println("  Total: $(round(sum(times), digits=2))s")
    println("  Throughput: $(round(N * length(datasets) / sum(times) / 1e6, digits=1)) Msamples/sec")
end

println("\n✅ All functions working with EDF and confidence intervals!")