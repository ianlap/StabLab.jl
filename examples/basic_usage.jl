# Basic Usage Example: StabLab.jl Frequency Stability Analysis

using Pkg
Pkg.activate("..")  # Activate StabLab package

using StabLab
using Random
using Plots

println("StabLab.jl Basic Usage Example")
println("=" ^ 40)

# Set seed for reproducible results
Random.seed!(42)

# Generate test data: White FM noise (random walk phase)
N = 10000
tau0 = 1.0  # 1 second sampling interval
phase_data = cumsum(randn(N)) * 1e-9  # Scale to realistic phase noise levels

println("Generated $N samples of White FM noise")
println("Sample interval: $tau0 seconds")
println("Phase noise level: ~$(round(std(phase_data) * 1e9, digits=2)) ns RMS")
println()

# Demonstrate different API patterns
println("=== API Patterns ===")

# Pattern 1: Single struct return (recommended)
result = adev(phase_data, tau0)
println("1. Struct return:")
println("   result.tau = $(result.tau[1:3])... ($(length(result.tau)) points)")
println("   result.deviation = $(round.(result.deviation[1:3], sigdigits=4))...")
println("   result.method = \"$(result.method)\"")

# Pattern 2: Multiple returns (MATLAB-style)
tau, dev = adev(phase_data, tau0, Val(2))
println()
println("2. Multiple returns:")
println("   tau, dev = adev(..., Val(2))")
println("   tau = $(tau[1:3])...")
println("   dev = $(round.(dev[1:3], sigdigits=4))...")

# Pattern 3: Custom parameters
result_custom = adev(phase_data, tau0, mlist=[1,2,4,8,16], confidence=0.95)
println()
println("3. Custom parameters:")
println("   Custom mlist: [1,2,4,8,16]")
println("   95% confidence intervals")
println("   Result: $(length(result_custom.tau)) tau points")

println()
println("=== All 10 Deviation Types ===")

# Test all deviation functions
functions = [
    ("adev", adev, "Allan deviation (fundamental)"),
    ("mdev", mdev, "Modified Allan deviation"),
    ("mhdev", mhdev, "Modified Hadamard deviation"),
    ("hdev", hdev, "Hadamard deviation"),
    ("mhtotdev", mhtotdev, "Modified Hadamard total deviation"),
    ("tdev", tdev, "Time deviation (seconds)"),
    ("ldev", ldev, "Lapinski deviation (seconds)"),
    ("totdev", totdev, "Total deviation"),
    ("mtotdev", mtotdev, "Modified total deviation"),
    ("htotdev", htotdev, "Hadamard total deviation")
]

results = Dict{String, Any}()

for (name, func, description) in functions
    result = func(phase_data, tau0)
    results[name] = result
    
    println("$(rpad(uppercase(name), 8)): $(rpad(string(length(result.tau)), 2)) points, " * 
           "first value = $(round(result.deviation[1], sigdigits=4)) - $description")
end

println()
println("=== Mathematical Relationships ===")

# Verify TDEV = τ × MDEV / √3
tdev_result = results["tdev"]
mdev_result = results["mdev"]
expected_tdev = tdev_result.tau[1] * mdev_result.deviation[1] / sqrt(3)
actual_tdev = tdev_result.deviation[1]

println("TDEV = τ × MDEV / √3 verification:")
println("  Expected: $(round(expected_tdev, sigdigits=6))")
println("  Actual:   $(round(actual_tdev, sigdigits=6))")
println("  Match: $(isapprox(expected_tdev, actual_tdev, rtol=0.01) ? "✓" : "✗")")

# Verify LDEV = τ × MHDEV / √(10/3)
ldev_result = results["ldev"]
mhdev_result = results["mhdev"]
expected_ldev = ldev_result.tau[1] * mhdev_result.deviation[1] / sqrt(10/3)
actual_ldev = ldev_result.deviation[1]

println()
println("LDEV = τ × MHDEV / √(10/3) verification:")
println("  Expected: $(round(expected_ldev, sigdigits=6))")
println("  Actual:   $(round(actual_ldev, sigdigits=6))")
println("  Match: $(isapprox(expected_ldev, actual_ldev, rtol=0.01) ? "✓" : "✗")")

println()
println("=== Creating Allan Deviation Plot ===")

# Create a typical Allan deviation plot
try
    # Plot Allan, Modified Allan, and Hadamard deviations
    plot_funcs = [("adev", "Allan"), ("mdev", "Modified Allan"), ("hdev", "Hadamard")]
    
    p = plot(xlabel="Averaging Time τ (s)", ylabel="Allan Deviation", 
             xscale=:log10, yscale=:log10, title="Frequency Stability Analysis",
             legend=:topright, grid=true)
    
    for (func_name, label) in plot_funcs
        result = results[func_name]
        plot!(p, result.tau, result.deviation, label=label, marker=:circle, linewidth=2)
    end
    
    # Add theoretical slope lines for reference
    tau_ref = [1, 100]
    
    # White PM slope: -1
    white_pm = result.deviation[1] * (tau_ref ./ result.tau[1]).^(-1)
    plot!(p, tau_ref, white_pm, line=:dash, color=:gray, alpha=0.5, label="White PM (slope -1)")
    
    # White FM slope: -0.5  
    white_fm = result.deviation[1] * (tau_ref ./ result.tau[1]).^(-0.5)
    plot!(p, tau_ref, white_fm, line=:dash, color=:gray, alpha=0.5, label="White FM (slope -0.5)")
    
    savefig(p, "examples/allan_deviation_plot.png")
    println("Allan deviation plot saved to examples/allan_deviation_plot.png")
    
catch e
    println("Could not create plot: $e")
end

println()
println("=== Performance Summary ===")
println("StabLab.jl provides:")
println("  • All 10 NIST SP1065 deviation types")
println("  • Exact MATLAB algorithm translations")
println("  • Type-safe, high-performance Julia implementation")
println("  • Flexible API supporting multiple return patterns")
println("  • Mathematical relationship validation")
println()
println("Example completed! Check examples/ directory for generated files.")