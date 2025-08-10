using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using StabLab
using Plots
using JSON3
using Random
using Printf
using Statistics

println("StabLab.jl vs AllanTools Validation (Automated)")
println("="^50)

# Load test datasets
test_data_file = joinpath(@__DIR__, "test_datasets.json")
if !isfile(test_data_file)
    println("Error: Test datasets not found. Run the AllanTools reference generation first.")
    exit(1)
end

println("Loading test datasets...")
test_data = JSON3.read(read(test_data_file, String))
datasets = test_data.datasets

# Test functions to validate
julia_functions = Dict(
    "adev" => (data, tau0) -> adev(data, tau0),
    "mdev" => (data, tau0) -> mdev(data, tau0),
    "tdev" => (data, tau0) -> tdev(data, tau0),
    "hdev" => (data, tau0) -> hdev(data, tau0),
    "totdev" => (data, tau0) -> totdev(data, tau0),
    "mtotdev" => (data, tau0) -> mtotdev(data, tau0),
    "tie" => (data, tau0) -> tie(data, tau0),
    "mtie" => (data, tau0) -> mtie(data, tau0),
    "pdev" => (data, tau0) -> pdev(data, tau0)
)

# Process each dataset
for (dataset_name, phase_data) in pairs(datasets)
    println("\n" * "="^60)
    println("Processing $dataset_name dataset")
    println("="^60)
    
    # Convert to Julia array
    julia_data = Vector{Float64}(phase_data)
    tau0 = 1.0
    
    # Load AllanTools reference for this dataset
    ref_file = joinpath(@__DIR__, "allantools_reference_$(dataset_name).json")
    if !isfile(ref_file)
        println("Warning: AllanTools reference not found for $dataset_name, skipping...")
        continue
    end
    
    println("Loading AllanTools reference: $(basename(ref_file))")
    allantools_data = JSON3.read(read(ref_file, String))
    allantools_results = allantools_data.results
    
    # Store comparison results
    comparison_results = Dict()
    plots_array = []
    
    # Compare each function
    for (func_name, julia_func) in julia_functions
        if !haskey(allantools_results, func_name)
            println("  Skipping $func_name (not in AllanTools reference)")
            continue
        end
        
        println("\n  Testing $func_name...")
        
        try
            # Compute Julia result
            julia_result = julia_func(julia_data, tau0)
            
            # Get AllanTools reference
            ref = allantools_results[func_name]
            ref_tau = Vector{Float64}(ref.tau)
            ref_dev = Vector{Float64}(ref.dev)
            
            # Find matching tau points for comparison
            matches = []
            for (i, jt) in enumerate(julia_result.tau)
                # Find closest AllanTools tau point
                idx = argmin(abs.(ref_tau .- jt))
                if abs(ref_tau[idx] - jt) < 0.1 * jt  # Within 10% of tau value
                    julia_val = julia_result.deviation[i]
                    ref_val = ref_dev[idx]
                    ratio = julia_val / ref_val
                    diff_pct = abs(julia_val - ref_val) / ref_val * 100
                    
                    push!(matches, (jt, julia_val, ref_val, ratio, diff_pct))
                end
            end
            
            if !isempty(matches)
                comparison_results[func_name] = matches
                
                println("    Comparison with AllanTools:")
                println("    τ (s)    | Julia      | AllanTools | Ratio   | Diff (%)")
                println("    " * "-"^55)
                
                for (tau, julia_val, ref_val, ratio, diff_pct) in matches[1:min(5, end)]
                    println(@sprintf("    %-8.1f | %-10.3e | %-10.3e | %-7.4f | %-7.2f%%",
                                   tau, julia_val, ref_val, ratio, diff_pct))
                end
                
                # Calculate statistics
                diff_pcts = [m[5] for m in matches]
                mean_diff = mean(diff_pcts)
                max_diff = maximum(diff_pcts)
                
                println(@sprintf("    Mean diff: %5.2f%%, Max diff: %5.2f%%, Points: %d",
                               mean_diff, max_diff, length(matches)))
                
                # Create comparison plot
                p = plot(julia_result.tau, julia_result.deviation,
                        marker=:circle, linewidth=2, markersize=3,
                        xscale=:log10, yscale=:log10,
                        xlabel="τ (s)", ylabel="Deviation",
                        title="$func_name - $dataset_name",
                        label="Julia StabLab.jl",
                        grid=true, minorgrid=true)
                
                # Add AllanTools reference points
                scatter!(p, ref_tau, ref_dev,
                        marker=:diamond, markersize=4,
                        label="AllanTools Reference",
                        color=:red, markerstrokewidth=1)
                
                push!(plots_array, p)
                
                # Color-code based on accuracy
                if mean_diff < 1.0
                    println("    ✓ Excellent agreement (mean diff < 1%)")
                elseif mean_diff < 5.0
                    println("    ⚠ Good agreement (mean diff < 5%)")
                else
                    println("    ✗ Poor agreement (mean diff ≥ 5%) - investigate")
                end
            else
                println("    Warning: No matching tau points found")
            end
            
        catch e
            println("    Error: $e")
        end
    end
    
    # Create combined plot for this dataset
    if !isempty(plots_array)
        n_plots = length(plots_array)
        layout_dims = (ceil(Int, sqrt(n_plots)), ceil(Int, n_plots / ceil(Int, sqrt(n_plots))))
        
        combined_plot = plot(plots_array...,
                           layout=layout_dims, size=(1200, 900),
                           plot_title="StabLab.jl vs AllanTools: $dataset_name Dataset",
                           titlefontsize=14)
        
        plot_filename = "validation/stablab_vs_allantools_$(dataset_name).png"
        savefig(combined_plot, plot_filename)
        println("\n  Saved plot: $plot_filename")
    end
    
    # Summary statistics for this dataset
    if !isempty(comparison_results)
        println("\n  ACCURACY SUMMARY for $dataset_name:")
        println("  " * "="^50)
        
        for (func_name, matches) in comparison_results
            diff_pcts = [m[5] for m in matches]
            mean_diff = mean(diff_pcts)
            max_diff = maximum(diff_pcts)
            min_diff = minimum(diff_pcts)
            
            status = mean_diff < 1.0 ? "✓" : (mean_diff < 5.0 ? "⚠" : "✗")
            
            println(@sprintf("  %s %-8s | Mean: %5.2f%% | Max: %5.2f%% | Min: %5.2f%% | Pts: %d",
                            status, uppercase(func_name), mean_diff, max_diff, min_diff, length(matches)))
        end
    end
end

# Create overall summary
println("\n" * "="^70)
println("OVERALL VALIDATION SUMMARY")
println("="^70)

println("Generated validation plots in validation/ directory:")
for dataset_name in keys(datasets)
    plot_file = "stablab_vs_allantools_$(dataset_name).png"
    if isfile(joinpath("validation", plot_file))
        println("  ✓ $plot_file")
    end
end

println("\nValidation complete!")
println("Check the generated plots and console output for detailed algorithm comparisons.")
println("\nNote: Functions showing >5% mean difference should be investigated for algorithm discrepancies.")