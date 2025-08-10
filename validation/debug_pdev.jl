using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using StabLab
using Random
using Printf

println("Debugging PDEV Implementation")
println("="^40)

# Create simple test data
Random.seed!(42)
N = 1000
phase_data = cumsum(randn(N)) * 1e-9
tau0 = 1.0

println("Test data: $N points")
println("Range: [$(@sprintf("%.3e", minimum(phase_data))), $(@sprintf("%.3e", maximum(phase_data)))]")

# Test PDEV for a few m values
test_m = [1, 2, 4, 8]

println("\nPDEV Results:")
println("m    | τ (s) | PDEV      | neff")
println("-"^35)

for m in test_m
    result = pdev(phase_data, tau0, m_list=[m])
    if !isempty(result.deviation) && !isnan(result.deviation[1])
        println(@sprintf("%-4d | %-5.1f | %-9.3e | %d",
                        m, result.tau[1], result.deviation[1], result.neff[1]))
    else
        println(@sprintf("%-4d | %-5.1f | NaN       | 0", m, m * tau0))
    end
end

# Compare ADEV at m=1 (should be equal)
println("\nValidating PDEV = ADEV at m=1:")
adev_result = adev(phase_data, tau0, mlist=[1])
pdev_result = pdev(phase_data, tau0, m_list=[1])

adev_1s = adev_result.deviation[1]
pdev_1s = pdev_result.deviation[1]
ratio = pdev_1s / adev_1s
diff_pct = abs(pdev_1s - adev_1s) / adev_1s * 100

println(@sprintf("ADEV(1s) = %.6e", adev_1s))
println(@sprintf("PDEV(1s) = %.6e", pdev_1s))
println(@sprintf("Ratio = %.6f, Diff = %.3f%%", ratio, diff_pct))

if diff_pct < 0.1
    println("✓ PDEV = ADEV at m=1 (within 0.1%)")
else
    println("✗ PDEV ≠ ADEV at m=1 - Algorithm error!")
end

# Check the normalization factor in the algorithm
println("\nDebugging normalization factor for m=2...")
m = 2
M = N - 2*m  
sum_sq = 0.0

for i in 0:M-1
    inner_sum = 0.0
    for k in 0:m-1
        weight = (m-1)/2.0 - k
        inner_sum += weight * (phase_data[i+k+1] - phase_data[i+k+m+1])
    end
    sum_sq += inner_sum^2
end

tau_val = m * tau0
variance_current = 72 * sum_sq / (M * m^4 * tau_val^2)
pdev_current = sqrt(variance_current)

println("Current algorithm:")
println(@sprintf("  M = %d, m = %d, tau = %.1f", M, m, tau_val))
println(@sprintf("  sum_sq = %.6e", sum_sq))
println(@sprintf("  variance = %.6e", variance_current))
println(@sprintf("  pdev = %.6e", pdev_current))

# Try alternative normalization (what might be correct)
println("\nTrying alternative normalization factors...")

# Option 1: Standard PDEV formula from literature
variance_alt1 = sum_sq / (M * tau_val^2)  # Without the 72/m^4 factor
pdev_alt1 = sqrt(variance_alt1)
println(@sprintf("Alt 1 (without 72/m^4): %.6e", pdev_alt1))

# Option 2: With different normalization
variance_alt2 = 6 * sum_sq / (M * m^2 * tau_val^2)  
pdev_alt2 = sqrt(variance_alt2)
println(@sprintf("Alt 2 (6/m^2 factor): %.6e", pdev_alt2))

println("\nPDEV debugging complete.")