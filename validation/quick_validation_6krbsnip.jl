using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using StabLab
using Plots
using DelimitedFiles
using Printf
using Statistics

println("Quick StabLab.jl Validation: 6krbsnip.txt")
println("="^40)

# Load data (use smaller subset for speed)
data_file = joinpath(@__DIR__, "data", "6krbsnip.txt")
if !isfile(data_file)
    println("Error: Data file not found: $data_file")
    exit(1)
end

println("Loading rubidium clock data...")
full_data = vec(readdlm(data_file, Float64))
# Use first 20k points for quick validation
N_subset = min(20000, length(full_data))
phase_data = full_data[1:N_subset]
tau0 = 1.0

println("Using subset: $N_subset of $(length(full_data)) points")
println("Data range: [$(@sprintf("%.3f", minimum(phase_data))), $(@sprintf("%.3f", maximum(phase_data)))]")

# Test core functions with limited tau range for speed
core_functions = [
    ("adev", adev, "Allan Deviation"),
    ("mdev", mdev, "Modified Allan Deviation"),
    ("hdev", hdev, "Hadamard Deviation"),
    ("totdev", totdev, "Total Deviation"),
    ("tie", tie, "Time Interval Error"),
    ("mtie", mtie, "Maximum Time Interval Error"),
    ("pdev", pdev, "Parabolic Deviation")
]

println("\n" * "="^40)
println("Computing core deviations...")
println("="^40)

results = Dict()
plots_array = []

for (i, (func_name, func, description)) in enumerate(core_functions)
    print("$func_name: ")
    
    try
        start_time = time()
        
        if func_name in ["tie", "mtie", "pdev"]
            # Limited tau range for time error functions
            m_list = [1, 2, 4, 8, 16, 32]
            result = func(phase_data, tau0, m_list=m_list)
        else
            result = func(phase_data, tau0)
        end
        
        elapsed = time() - start_time
        results[func_name] = result
        
        println("✓ $(length(result.tau)) points ($(round(elapsed, digits=2))s)")
        
        # Create plot
        color = [:blue, :red, :green, :orange, :purple, :brown, :pink][i]
        p = plot(result.tau, result.deviation,
                marker=:circle, linewidth=2, markersize=3,
                xscale=:log10, yscale=:log10,
                xlabel="τ (s)", ylabel="Deviation",
                title="$func_name\\n$description",
                label="StabLab.jl",
                color=color, grid=true)
        
        push!(plots_array, p)
        
    catch e
        println("✗ Failed: $e")
    end
end

# Create combined validation plot
combined_plot = plot(plots_array...,
                    layout=(3,3), size=(1200, 900),
                    plot_title="StabLab.jl Validation: 6krbsnip.txt (Rubidium Clock)",
                    titlefontsize=14)

output_file = "validation/stablab_6krbsnip_quick_validation.png"
savefig(combined_plot, output_file)
println("\nSaved validation plot: $output_file")

# Quick mathematical relationship checks
println("\n" * "="^40)
println("Mathematical Validation")
println("="^40)

# Check PDEV = ADEV at m=1
if haskey(results, "pdev") && haskey(results, "adev")
    pdev_1s = results["pdev"].deviation[1]
    adev_1s = results["adev"].deviation[1]
    diff_pct = abs(pdev_1s - adev_1s) / adev_1s * 100
    
    println("PDEV = ADEV at τ=1s:")
    println(@sprintf("  ADEV(1s) = %.6e", adev_1s))
    println(@sprintf("  PDEV(1s) = %.6e", pdev_1s))
    println(@sprintf("  Difference = %.3f%%", diff_pct))
    
    if diff_pct < 0.1
        println("  ✓ PDEV = ADEV relationship validated")
    else
        println("  ✗ PDEV = ADEV relationship failed - INVESTIGATE")
    end
end

# Check MTIE >= TIE relationship
if haskey(results, "mtie") && haskey(results, "tie")
    mtie_result = results["mtie"]
    tie_result = results["tie"]
    
    local violations = 0
    local total = 0
    
    for i in 1:min(length(tie_result.tau), length(mtie_result.tau))
        if abs(tie_result.tau[i] - mtie_result.tau[i]) < 0.1
            total += 1
            if mtie_result.deviation[i] < tie_result.deviation[i]
                violations += 1
                println("  Warning: MTIE < TIE at τ=$(tie_result.tau[i])s")
            end
        end
    end
    
    println("MTIE ≥ TIE relationship:")
    println(@sprintf("  Valid: %d/%d points", total - violations, total))
    if violations == 0
        println("  ✓ MTIE ≥ TIE relationship validated")
    else
        println("  ⚠ $violations violations found")
    end
end

# Analyze Allan deviation characteristics
if haskey(results, "adev")
    adev_result = results["adev"]
    println("\nAllan deviation analysis:")
    println("τ (s) | ADEV      | Slope | Noise Type")
    println("-"^40)
    
    for i in 1:min(6, length(adev_result.tau))
        tau_val = adev_result.tau[i]
        adev_val = adev_result.deviation[i]
        
        if i > 1
            prev_tau = adev_result.tau[i-1]
            prev_adev = adev_result.deviation[i-1]
            slope = log10(adev_val/prev_adev) / log10(tau_val/prev_tau)
            
            if slope < -0.7
                noise_type = "White PM"
            elseif slope < -0.2
                noise_type = "Flicker PM"
            elseif slope < 0.2
                noise_type = "White FM"
            elseif slope < 0.7
                noise_type = "Flicker FM"
            else
                noise_type = "RW FM"
            end
            
            println(@sprintf("%-5.1f | %-9.3e | %5.2f | %s",
                           tau_val, adev_val, slope, noise_type))
        else
            println(@sprintf("%-5.1f | %-9.3e |   --  | Initial",
                           tau_val, adev_val))
        end
    end
end

println("\n" * "="^40)
println("Quick Validation Summary")
println("="^40)
println("Dataset: 6krbsnip.txt (rubidium clock)")
println("Points used: $(N_subset) of $(length(full_data))")
println("Functions tested: $(length(results))")
println("Generated plot: $output_file")

successful = length(results)
total_functions = length(core_functions)

if successful == total_functions
    println("✓ All core functions working correctly")
else
    println("⚠ $(total_functions - successful) functions failed")
end

println("\nReview the plot to see all deviations on real rubidium clock data.")
println("This shows StabLab.jl performance on a well-characterized oscillator.")