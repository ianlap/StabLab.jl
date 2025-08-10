using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using StabLab
using Plots
using DelimitedFiles
using Printf
using Statistics

println("Comprehensive StabLab.jl Validation with 6krbsnip.txt")
println("="^55)

# Load the rubidium clock snippet data
data_file = joinpath(@__DIR__, "data", "6krbsnip.txt")

if !isfile(data_file)
    println("Error: Data file not found: $data_file")
    exit(1)
end

println("Loading rubidium clock data: 6krbsnip.txt")
phase_data = vec(readdlm(data_file, Float64))
tau0 = 1.0

N = length(phase_data)
data_range = [minimum(phase_data), maximum(phase_data)]

println("Loaded $N data points")
println("Sampling interval τ₀ = $tau0 s")
println("Data range: [$(@sprintf("%.6f", data_range[1])), $(@sprintf("%.6f", data_range[2]))]")
println("Data statistics:")
println("  Mean: $(@sprintf("%.6f", mean(phase_data)))")
println("  Std:  $(@sprintf("%.6e", std(phase_data)))")
println("  Duration: $(N * tau0) seconds")

# Test all StabLab.jl functions
println("\n" * "="^55)
println("Computing all StabLab.jl deviations...")
println("="^55)

julia_results = Dict()
test_functions = [
    ("adev", adev, "Allan Deviation (Overlapping)"),
    ("mdev", mdev, "Modified Allan Deviation"), 
    ("tdev", tdev, "Time Deviation"),
    ("hdev", hdev, "Hadamard Deviation (Overlapping)"),
    ("mhdev", mhdev, "Modified Hadamard Deviation"),
    ("ldev", ldev, "Lapinski Deviation"),
    ("totdev", totdev, "Total Deviation"),
    ("mtotdev", mtotdev, "Modified Total Deviation"),
    ("htotdev", htotdev, "Hadamard Total Deviation"),
    ("mhtotdev", mhtotdev, "Modified Hadamard Total Deviation"),
    ("tie", tie, "Time Interval Error"),
    ("mtie", mtie, "Maximum Time Interval Error"),
    ("pdev", pdev, "Parabolic Deviation"),
    ("theo1", theo1, "Theo1 Deviation")
]

computation_times = Dict()

for (func_name, func, description) in test_functions
    print("  $(rpad(func_name, 8)): $description... ")
    
    try
        # Time the computation
        start_time = time()
        
        if func_name in ["tie", "mtie", "pdev", "theo1"]
            # Use smaller m_list for these functions
            max_m = min(100, N ÷ 20)
            m_list = unique([1; 2:2:10; [2^k for k in 2:floor(Int, log2(max_m))]])
            result = func(phase_data, tau0, m_list=m_list)
        else
            result = func(phase_data, tau0)
        end
        
        elapsed = time() - start_time
        computation_times[func_name] = elapsed
        
        julia_results[func_name] = result
        
        println("✓ $(length(result.tau)) points ($(round(elapsed, digits=3))s)")
        
    catch e
        println("✗ Failed: $e")
        computation_times[func_name] = NaN
    end
end

# Create comprehensive validation plots
println("\n" * "="^55)
println("Creating validation plots...")
println("="^55)

# Prepare plots in a grid
plots_array = []
colors = [:blue, :red, :green, :orange, :purple, :brown, :pink, :gray, :olive, :cyan, :magenta, :black, :yellow, :lightblue]

for (i, (func_name, func, description)) in enumerate(test_functions)
    if !haskey(julia_results, func_name)
        continue
    end
    
    result = julia_results[func_name]
    color = colors[min(i, length(colors))]
    
    # Create individual plot
    p = plot(result.tau, result.deviation,
            marker=:circle, linewidth=2, markersize=3,
            xscale=:log10, yscale=:log10,
            xlabel="τ (s)", ylabel="Deviation",
            title="$func_name\\n$description",
            label="StabLab.jl",
            color=color, grid=true, minorgrid=true,
            legendfontsize=8, titlefontsize=10)
    
    # Add theoretical slopes for some functions
    if func_name == "adev" && length(result.tau) >= 3
        # Fit a line to estimate slope in log-log space
        log_tau = log10.(result.tau[2:end])
        log_dev = log10.(result.deviation[2:end])
        
        # Simple linear regression for slope
        n = length(log_tau)
        slope = (n * sum(log_tau .* log_dev) - sum(log_tau) * sum(log_dev)) / 
                (n * sum(log_tau.^2) - sum(log_tau)^2)
        
        # Add slope annotation
        plot!(p, annotation=(0.02, 0.98, text("Slope ≈ $(round(slope, digits=2))", 10, :left)), 
              subplot=1, annotationfontsize=8, transform=:axis)
    end
    
    push!(plots_array, p)
end

# Create the combined plot
n_plots = length(plots_array)
if n_plots <= 4
    layout = (2, 2)
    size_tuple = (1000, 800)
elseif n_plots <= 6  
    layout = (2, 3)
    size_tuple = (1200, 800)
elseif n_plots <= 9
    layout = (3, 3) 
    size_tuple = (1200, 1200)
else
    layout = (4, 4)
    size_tuple = (1600, 1200)
end

# Create combined plot
combined_plot = plot(plots_array[1:min(16, n_plots)]...,
                    layout=layout, size=size_tuple,
                    plot_title="StabLab.jl Comprehensive Validation\\n6krbsnip.txt (Rubidium Clock)",
                    titlefontsize=16, margin=5Plots.mm)

# Save the plot
output_file = "validation/stablab_validation_6krbsnip_comprehensive.png"
savefig(combined_plot, output_file)
println("Saved comprehensive validation plot: $output_file")

# Create a performance summary
println("\n" * "="^55)
println("PERFORMANCE SUMMARY")
println("="^55)
println("Function  | Points | Time (s) | Rate (pts/s)")
println("-"^45)

total_time = 0.0
total_points = 0

for (func_name, _, _) in test_functions
    if haskey(julia_results, func_name) && haskey(computation_times, func_name)
        result = julia_results[func_name]
        elapsed = computation_times[func_name]
        n_points = length(result.tau)
        rate = n_points / elapsed
        
        total_time += elapsed
        total_points += n_points
        
        println(@sprintf("%-9s | %6d | %8.3f | %10.1f",
                        func_name, n_points, elapsed, rate))
    end
end

println("-"^45)
println(@sprintf("%-9s | %6d | %8.3f | %10.1f",
                "TOTAL", total_points, total_time, total_points/total_time))

# Data characteristics analysis
println("\n" * "="^55)
println("DATA CHARACTERISTICS ANALYSIS")
println("="^55)

if haskey(julia_results, "adev")
    adev_result = julia_results["adev"]
    
    println("Allan deviation analysis:")
    println("τ (s)     | ADEV      | Expected for")
    println("-"^40)
    
    for i in 1:min(6, length(adev_result.tau))
        tau_val = adev_result.tau[i]
        adev_val = adev_result.deviation[i]
        
        # Determine noise type based on slope
        if i > 1
            prev_tau = adev_result.tau[i-1]
            prev_adev = adev_result.deviation[i-1]
            slope = log10(adev_val/prev_adev) / log10(tau_val/prev_tau)
            
            if slope < -0.7
                noise_type = "White PM"
            elseif slope < -0.3
                noise_type = "Flicker PM"  
            elseif slope < 0.3
                noise_type = "White FM"
            elseif slope < 0.7
                noise_type = "Flicker FM"
            else
                noise_type = "RW FM"
            end
        else
            noise_type = "Initial"
        end
        
        println(@sprintf("%-9.1f | %-9.3e | %s",
                        tau_val, adev_val, noise_type))
    end
end

# Validate mathematical relationships
println("\n" * "="^55)
println("MATHEMATICAL RELATIONSHIP VALIDATION")  
println("="^55)

validation_checks = []

# Check TDEV = τ × MDEV / √3
if haskey(julia_results, "tdev") && haskey(julia_results, "mdev")
    tdev_result = julia_results["tdev"]
    mdev_result = julia_results["mdev"]
    
    println("TDEV vs MDEV relationship (TDEV = τ × MDEV / √3):")
    println("τ (s) | TDEV      | τ×MDEV/√3 | Diff (%)")
    println("-"^45)
    
    for i in 1:min(5, length(tdev_result.tau))
        tau_val = tdev_result.tau[i]
        tdev_val = tdev_result.deviation[i]
        
        # Find corresponding MDEV value
        mdev_idx = argmin(abs.(mdev_result.tau .- tau_val))
        if abs(mdev_result.tau[mdev_idx] - tau_val) < 0.1
            mdev_val = mdev_result.deviation[mdev_idx]
            expected = tau_val * mdev_val / sqrt(3)
            diff_pct = abs(tdev_val - expected) / expected * 100
            
            push!(validation_checks, ("TDEV relationship", diff_pct))
            
            println(@sprintf("%-5.1f | %-9.3e | %-9.3e | %6.2f",
                           tau_val, tdev_val, expected, diff_pct))
        end
    end
end

# Check PDEV = ADEV at m=1
if haskey(julia_results, "pdev") && haskey(julia_results, "adev")
    pdev_result = julia_results["pdev"]
    adev_result = julia_results["adev"]
    
    if !isempty(pdev_result.tau) && !isempty(adev_result.tau)
        pdev_1s = pdev_result.deviation[1]
        adev_1s = adev_result.deviation[1]
        diff_pct = abs(pdev_1s - adev_1s) / adev_1s * 100
        
        push!(validation_checks, ("PDEV = ADEV at m=1", diff_pct))
        
        println("\\nPDEV = ADEV at τ=1s validation:")
        println(@sprintf("  ADEV(1s) = %.6e", adev_1s))
        println(@sprintf("  PDEV(1s) = %.6e", pdev_1s))
        println(@sprintf("  Difference = %.3f%%", diff_pct))
        
        if diff_pct < 0.1
            println("  ✓ PDEV = ADEV relationship validated")
        else
            println("  ✗ PDEV = ADEV relationship failed")
        end
    end
end

# Check MTIE >= TIE relationship
if haskey(julia_results, "mtie") && haskey(julia_results, "tie")
    mtie_result = julia_results["mtie"]
    tie_result = julia_results["tie"]
    
    violations = 0
    total_checks = 0
    
    println("\\nMTIE ≥ TIE relationship validation:")
    for i in 1:min(length(tie_result.tau), length(mtie_result.tau))
        if abs(tie_result.tau[i] - mtie_result.tau[i]) < 0.01
            if mtie_result.deviation[i] < tie_result.deviation[i]
                violations += 1
            end
            total_checks += 1
        end
    end
    
    println(@sprintf("  Valid: %d/%d points (%.1f%%)", 
                    total_checks - violations, total_checks, 
                    100.0 * (total_checks - violations) / total_checks))
    
    if violations == 0
        println("  ✓ MTIE ≥ TIE relationship validated")
    else
        println("  ⚠ MTIE < TIE at $violations points")
    end
end

# Final validation summary
println("\\n" * "="^55)
println("VALIDATION SUMMARY")
println("="^55)

functions_computed = length(julia_results)
total_tau_points = sum(length(r.tau) for r in values(julia_results))

println("Functions successfully computed: $functions_computed/$(length(test_functions))")
println("Total tau points computed: $total_tau_points")
println("Total computation time: $(round(total_time, digits=2)) seconds")
println("Average rate: $(round(total_tau_points/total_time, digits=1)) points/second")

if !isempty(validation_checks)
    println("\\nMathematical relationship validation:")
    for (check_name, error_pct) in validation_checks
        status = error_pct < 1.0 ? "✓" : (error_pct < 5.0 ? "⚠" : "✗")
        println("  $status $check_name: $(round(error_pct, digits=3))% error")
    end
end

println("\\nGenerated files:")
println("  $output_file")

println("\\nStabLab.jl comprehensive validation complete!")
println("Review the plot to see all deviation functions on the rubidium clock data.")

# Also create a simple comparison plot with expected slopes
slope_plot = plot(size=(800, 600), title="6krbsnip.txt: Allan Deviation with Theoretical Slopes")

if haskey(julia_results, "adev")
    adev_result = julia_results["adev"]
    plot!(slope_plot, adev_result.tau, adev_result.deviation,
          marker=:circle, linewidth=2, markersize=4,
          xscale=:log10, yscale=:log10,
          xlabel="τ (s)", ylabel="Allan Deviation",
          label="Measured ADEV", color=:blue)
    
    # Add theoretical slope lines
    tau_ref = adev_result.tau
    adev_ref = adev_result.deviation
    
    if length(tau_ref) >= 3
        mid_idx = length(tau_ref) ÷ 2
        ref_tau = tau_ref[mid_idx]
        ref_adev = adev_ref[mid_idx]
        
        # τ^(-1/2) slope (White PM)
        white_pm = ref_adev .* (tau_ref ./ ref_tau).^(-0.5)
        plot!(slope_plot, tau_ref, white_pm, line=:dash, linewidth=2,
              label="τ^(-1/2) White PM", color=:red, alpha=0.7)
        
        # τ^0 slope (White FM)  
        white_fm = ref_adev .* (tau_ref ./ ref_tau).^0
        plot!(slope_plot, tau_ref, white_fm, line=:dash, linewidth=2,
              label="τ^0 White FM", color=:green, alpha=0.7)
        
        # τ^(1/2) slope (Random Walk FM)
        rw_fm = ref_adev .* (tau_ref ./ ref_tau).^0.5
        plot!(slope_plot, tau_ref, rw_fm, line=:dash, linewidth=2,
              label="τ^(1/2) RW FM", color=:orange, alpha=0.7)
    end
end

savefig(slope_plot, "validation/6krbsnip_adev_with_slopes.png")
println("  validation/6krbsnip_adev_with_slopes.png")