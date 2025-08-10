# Test optimized ADEV implementation

using Pkg
Pkg.activate("..")

using StabLab
using Random

function optimized_adev_core(x::Vector{Float64}, tau0::Float64, mlist::Vector{Int})
    """Optimized ADEV core computation without noise_id"""
    N = length(x)
    adev_vals = zeros(length(mlist))
    neff = zeros(Int, length(mlist))
    
    @inbounds for (k, m) in enumerate(mlist)
        L = N - 2*m
        if L <= 0
            break
        end
        neff[k] = L
        
        # In-place computation to avoid allocations
        sum_d2_squared = 0.0
        @simd for i in 1:L
            d2 = x[i + 2*m] - 2*x[i + m] + x[i]
            sum_d2_squared += d2 * d2
        end
        
        avar = sum_d2_squared / (L * 2 * m^2 * tau0^2)
        adev_vals[k] = sqrt(avar)
    end
    
    return adev_vals, neff
end

function performance_comparison()
    println("⚡ OPTIMIZED vs CURRENT ADEV PERFORMANCE")
    println("=" ^ 50)
    
    # Test data
    Random.seed!(42)
    N = 100_000
    x = cumsum(randn(N)) * 1e-9
    tau0 = 1.0
    mlist = [1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096]
    
    println("Test: $N samples, $(length(mlist)) tau points")
    
    # Current implementation
    println("\n📊 Current StabLab.jl ADEV:")
    start = time()
    result_current = adev(x, tau0)
    time_current = time() - start
    println("  Time: $(round(time_current, digits=3))s")
    println("  Values: $(result_current.deviation[1:3])")
    
    # Optimized core (no noise_id, in-place computation)
    println("\n⚡ Optimized core (no noise_id):")
    start = time()
    adev_vals_opt, neff_opt = optimized_adev_core(x, tau0, mlist)
    time_optimized = time() - start
    println("  Time: $(round(time_optimized, digits=3))s")
    println("  Values: $(adev_vals_opt[1:3])")
    
    # Performance improvement
    speedup = time_current / time_optimized
    println("\n🚀 Performance Improvement:")
    println("  Speedup: $(round(speedup, digits=1))x faster")
    println("  Time reduction: $(round((1 - time_optimized/time_current)*100, digits=1))%")
    
    # Verify correctness
    println("\n✅ Correctness check:")
    max_diff = maximum(abs.(result_current.deviation[1:length(adev_vals_opt)] - adev_vals_opt))
    println("  Max difference: $(max_diff)")
    println("  Relative error: $(round(max_diff/mean(adev_vals_opt)*100, digits=6))%")
    
    return speedup
end

if abspath(PROGRAM_FILE) == @__FILE__
    performance_comparison()
end