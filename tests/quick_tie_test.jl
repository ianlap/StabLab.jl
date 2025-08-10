using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using StabLab
using Random
using Printf

println("Quick TIE Algorithm Test")
println("="^40)

# Use same seed as Python comparison
Random.seed!(42)

# Generate same test data
N = 10000
tau0 = 1.0
phase_data = cumsum(randn(N) * 1e-9)

println("Test data: $(N) points")
println("Sample values: $(phase_data[1:3])")

# Test our corrected TIE
tie_result = tie(phase_data, tau0)

println("\nTIE Results:")
println("Tau points: $(length(tie_result.tau))")

# Compare with expected AllanTools values from our earlier run
expected_values = [
    (1.0, 1.003e-09),
    (2.0, 1.409e-09), 
    (4.0, 1.968e-09),
    (8.0, 2.747e-09)
]

println("\nComparison with expected AllanTools values:")
println("τ (s)    | Julia TIE  | Expected   | Ratio   | Diff (%)")
println("-"^55)

for (exp_tau, exp_val) in expected_values
    # Find closest tau
    julia_idx = argmin(abs.(tie_result.tau .- exp_tau))
    if abs(tie_result.tau[julia_idx] - exp_tau) < 0.1
        julia_val = tie_result.deviation[julia_idx]
        ratio = julia_val / exp_val
        diff_pct = abs(julia_val - exp_val) / exp_val * 100
        
        println(@sprintf("%-8.1f | %-10.3e | %-10.3e | %-7.4f | %-7.2f",
                        exp_tau, julia_val, exp_val, ratio, diff_pct))
    end
end

# Manual verification of algorithm
println("\nManual verification for τ=1s (m=1):")
m = 1
n_pairs = N - m
manual_tie_vals = zeros(n_pairs)
for i in 1:n_pairs
    pair_max = max(phase_data[i], phase_data[i+m])
    pair_min = min(phase_data[i], phase_data[i+m])
    manual_tie_vals[i] = pair_max - pair_min
end
manual_tie = sqrt(sum(manual_tie_vals.^2) / length(manual_tie_vals))

manual_str = @sprintf("%.9e", manual_tie)
function_str = @sprintf("%.9e", tie_result.deviation[1])
println("Manual calculation: $(manual_str)")
println("Function result:     $(function_str)")
println("Match: $(abs(manual_tie - tie_result.deviation[1]) < 1e-15 ? "YES" : "NO")")

println("\nTIE algorithm test complete!")