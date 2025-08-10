using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using StabLab
using Random
using Printf

println("Quick MTIE Algorithm Test")
println("="^40)

# Use same seed as Python comparison
Random.seed!(42)

# Generate same test data
N = 10000
tau0 = 1.0
phase_data = cumsum(randn(N) * 1e-9)

println("Test data: $(N) points")

# Test our corrected MTIE
mtie_result = mtie(phase_data, tau0)

println("\nMTIE Results:")
println("Tau points: $(length(mtie_result.tau))")

# Compare with expected AllanTools values from our earlier run
expected_values = [
    (1.0, 3.926e-09),
    (2.0, 5.696e-09), 
    (4.0, 7.432e-09),
    (8.0, 1.013e-08),
    (16.0, 1.475e-08),
    (32.0, 1.962e-08)
]

println("\nComparison with expected AllanTools values:")
println("τ (s)    | Julia MTIE | Expected   | Ratio   | Diff (%)")
println("-"^55)

for (exp_tau, exp_val) in expected_values
    # Find closest tau
    julia_idx = argmin(abs.(mtie_result.tau .- exp_tau))
    if abs(mtie_result.tau[julia_idx] - exp_tau) < 0.1
        julia_val = mtie_result.deviation[julia_idx]
        ratio = julia_val / exp_val
        diff_pct = abs(julia_val - exp_val) / exp_val * 100
        
        println(@sprintf("%-8.1f | %-10.3e | %-10.3e | %-7.4f | %-7.2f",
                        exp_tau, julia_val, exp_val, ratio, diff_pct))
    end
end

# Manual verification for small m
println("\nManual verification for τ=2s (m=2):")
m = 2
window_size = m + 1  # AllanTools uses m+1
n_windows = N - m

function compute_manual_mtie(data, m)
    window_size = m + 1
    n_windows = length(data) - m
    max_tie = 0.0
    for i in 1:n_windows
        window = @view data[i:i+m]  # Window of size m+1
        tie = maximum(window) - minimum(window)
        max_tie = max(max_tie, tie)
    end
    return max_tie
end

manual_max_tie = compute_manual_mtie(phase_data, m)

# Find τ=2s result
tau_2s_idx = argmin(abs.(mtie_result.tau .- 2.0))
function_result = mtie_result.deviation[tau_2s_idx]

manual_str = @sprintf("%.9e", manual_max_tie)
function_str = @sprintf("%.9e", function_result)
println("Manual calculation: $(manual_str)")
println("Function result:     $(function_str)")
println("Match: $(abs(manual_max_tie - function_result) < 1e-15 ? "YES" : "NO")")

println("\nMTIE algorithm test complete!")