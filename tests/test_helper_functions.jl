# Test script for new helper functions: noise_id, compute_ci

using Pkg
Pkg.activate("..")

using StabLab
using Random
using Statistics

println("Testing StabLab.jl Helper Functions")
println("=" ^ 40)

# Generate test data
Random.seed!(42)
N = 10000
tau0 = 1.0
phase_data = cumsum(randn(N)) * 1e-9

println("Generated $N samples of White FM noise")
println("Phase noise level: ~$(round(std(phase_data) * 1e9, digits=2)) ns RMS")
println()

# Test basic deviation calculation
print("Testing ADEV computation... ")
result = adev(phase_data, tau0)
println("✓ $(length(result.tau)) tau points")

# Test confidence interval calculation
print("Testing confidence intervals... ")
result_with_ci = compute_ci(result, 0.683)
ci_width = result_with_ci.ci[1,2] - result_with_ci.ci[1,1]
println("✓ CI width at τ=1s: $(round(ci_width*1e9, digits=2)) ns")
println("  EDF at τ=1s: $(round(result_with_ci.edf[1], digits=1))")

# Test noise identification
print("Testing noise identification... ")
m_list = [1, 2, 4, 8, 16]
alphas = noise_id(phase_data, m_list, "phase")
valid_alphas = filter(!isnan, alphas)
println("✓ $(length(valid_alphas))/$(length(alphas)) valid estimates")
println("  Alpha values: $alphas")
println("  Expected: 0 (White FM)")

# Test all deviation types with CI
println("\nTesting all deviation types with confidence intervals:")
functions = [
    ("adev", adev, "Allan deviation"),
    ("mdev", mdev, "Modified Allan deviation"),
    ("hdev", hdev, "Hadamard deviation"),
    ("mhdev", mhdev, "Modified Hadamard deviation")
]

for (name, func, description) in functions
    try
        result = func(phase_data, tau0)
        result_with_ci = compute_ci(result, 0.683)
        edf_val = result_with_ci.edf[1]
        ci_width = result_with_ci.ci[1,2] - result_with_ci.ci[1,1]
        
        println("$(rpad(uppercase(name), 6)): dev=$(round(result.deviation[1]*1e9, digits=2))ns, " * 
               "edf=$(round(edf_val, digits=1)), " *
               "ci_width=$(round(ci_width*1e9, digits=1))ns - $description")
    catch e
        println("$(rpad(uppercase(name), 6)): FAILED - $e")
    end
end

println("\n✅ Helper function tests completed!")
println("StabLab.jl now supports:")
println("  • Automatic noise identification")  
println("  • EDF-based confidence intervals")
println("  • Chi-squared statistical bounds")
println("  • Fallback Gaussian intervals")