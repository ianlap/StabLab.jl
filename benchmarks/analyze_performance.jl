# Simple performance analysis without extra packages

using Pkg
Pkg.activate("..")

using StabLab
using Random

function analyze_adev_performance()
    println("🔍 ANALYZING JULIA ADEV PERFORMANCE")
    println("=" ^ 40)
    
    # Create test data
    Random.seed!(42)
    N = 50_000  # Medium size for analysis
    phase_data = cumsum(randn(N)) * 1e-9
    tau0 = 1.0
    
    println("Test data: $N samples")
    println("Memory: ~$(N * 8 / 1024^2:.1f) MB")
    println()
    
    # Time different parts
    println("🕐 Timing breakdown:")
    
    # Full function
    start = time()
    result = adev(phase_data, tau0)
    total_time = time() - start
    println("  Total ADEV time: $(round(total_time, digits=3))s")
    println("  Tau points: $(length(result.tau))")
    println("  Time per tau point: $(round(total_time/length(result.tau), digits=4))s")
    
    # Memory usage estimate
    tau_points = length(result.tau)
    estimated_memory = N * tau_points * 8 / 1024^2  # Rough estimate
    println("  Estimated working memory: ~$(round(estimated_memory, digits=1)) MB")
    
    # Compare with a simple operation
    start = time()
    simple_sum = sum(phase_data)
    simple_time = time() - start
    println("  Simple sum time: $(round(simple_time * 1000, digits=2))ms")
    println("  ADEV vs sum ratio: $(round(total_time/simple_time, digits=0))x slower")
    
    # Test scaling
    println("\n📈 Scaling analysis:")
    sizes = [1000, 5000, 10000, 25000]
    
    for N_test in sizes
        if N_test <= N
            test_data = phase_data[1:N_test]
            start = time()
            test_result = adev(test_data, tau0)
            test_time = time() - start
            
            throughput = N_test / test_time / 1000  # ksamples/sec
            println("  N=$N_test: $(round(test_time, digits=3))s ($(round(throughput, digits=1)) kSmp/s)")
        end
    end
    
    return result
end

if abspath(PROGRAM_FILE) == @__FILE__
    analyze_adev_performance()
end