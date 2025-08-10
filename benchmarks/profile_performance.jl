# Profile Julia performance to find bottlenecks

using Pkg
Pkg.activate("..")

using StabLab
using Random
using BenchmarkTools
using Profile

function profile_adev()
    println("🔍 PROFILING JULIA PERFORMANCE")
    println("=" ^ 40)
    
    # Create test data similar to benchmark
    Random.seed!(42)
    N = 100_000  # Smaller for detailed profiling
    phase_data = cumsum(randn(N)) * 1e-9
    tau0 = 1.0
    
    println("Profiling ADEV with $N samples...")
    
    # Warm up (JIT compilation)
    result = adev(phase_data, tau0)
    println("Warm-up complete: $(length(result.tau)) tau points")
    
    # Benchmark
    println("\n📊 Benchmarking:")
    bench_result = @benchmark adev($phase_data, $tau0) samples=5 seconds=30
    println(bench_result)
    
    # Profile to find bottlenecks
    println("\n🔍 Profiling (collecting data...):")
    Profile.clear()
    @profile begin
        for i in 1:10
            adev(phase_data, tau0)
        end
    end
    
    Profile.print(maxdepth=15, mincount=10)
    
    return bench_result
end

if abspath(PROGRAM_FILE) == @__FILE__
    profile_adev()
end