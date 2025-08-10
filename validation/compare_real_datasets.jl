using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using StabLab
using Plots
using JSON3
using DelimitedFiles
using Printf
using Statistics

println("StabLab.jl Real Dataset Validation")
println("="^40)

# Test dataset definitions
test_datasets = [
    ("6krb25apr", "Rubidium clock full dataset"),
    ("6krbsnip", "Rubidium clock snippet"),
    ("mx_w10_pem7", "GPS receiver data")
]

# Julia functions to test
julia_functions = Dict(
    "adev" => (data, tau0) -> adev(data, tau0),
    "mdev" => (data, tau0) -> mdev(data, tau0),
    "tdev" => (data, tau0) -> tdev(data, tau0),
    "hdev" => (data, tau0) -> hdev(data, tau0),
    "totdev" => (data, tau0) -> totdev(data, tau0),
    "mtotdev" => (data, tau0) -> mtotdev(data, tau0),
    "mhdev" => (data, tau0) -> mhdev(data, tau0),
    "mhtotdev" => (data, tau0) -> mhtotdev(data, tau0),
    "tie" => (data, tau0) -> tie(data, tau0),
    "mtie" => (data, tau0) -> mtie(data, tau0),
    "pdev" => (data, tau0) -> pdev(data, tau0)
)

# Store all results for final summary
all_results = Dict()

# Process each dataset
for (dataset_name, description) in test_datasets
    println("\n" * "="^60)
    println("Processing $dataset_name: $description")
    println("="^60)
    
    # Load phase data
    phase_data_file = joinpath(@__DIR__, "phase_data_$(dataset_name).json")
    if !isfile(phase_data_file)
        println("Warning: Phase data file not found: $(basename(phase_data_file))")
        println("Skipping $dataset_name...")
        continue
    end
    
    println("Loading phase data: $(basename(phase_data_file))")
    phase_info = JSON3.read(read(phase_data_file, String))
    phase_data = Vector{Float64}(phase_info.phase_data)
    tau0 = phase_info.tau0
    
    println("Loaded $(length(phase_data)) points, τ₀ = $tau0 s")
    data_range = [minimum(phase_data), maximum(phase_data)]
    println("Range: [$(@sprintf("%.3e", data_range[1])), $(@sprintf("%.3e", data_range[2]))]")
    
    # Compute Julia results for all functions
    julia_results = Dict()
    
    println("\nComputing StabLab.jl deviations...")
    for (func_name, julia_func) in julia_functions
        try
            print("  $func_name... ")
            result = julia_func(phase_data, tau0)
            julia_results[func_name] = result
            println("✓ $(length(result.tau)) points")
        catch e
            println("✗ Failed: $e")
        end
    end
    
    # Load AllanTools reference if available
    allantools_file = joinpath(@__DIR__, "allantools_reference_$(dataset_name).json")
    allantools_available = isfile(allantools_file)
    
    # Load MATLAB reference if available  
    matlab_file = joinpath(@__DIR__, "matlab_reference_$(dataset_name).json")
    matlab_available = isfile(matlab_file)
    
    # Comparison results for this dataset
    dataset_results = Dict(
        "julia" => julia_results,
        "dataset_info" => phase_info,
        "comparisons" => Dict()
    )
    
    # Compare with AllanTools if available
    if allantools_available
        println("\nComparing with AllanTools reference...")
        allantools_data = JSON3.read(read(allantools_file, String))
        allantools_results = allantools_data.results
        
        dataset_results["comparisons"]["allantools"] = compare_with_reference(
            julia_results, allantools_results, "AllanTools"
        )
    else
        println("AllanTools reference not available for $dataset_name")
    end
    
    # Compare with MATLAB if available
    if matlab_available
        println("\nComparing with MATLAB reference...")
        matlab_data = JSON3.read(read(matlab_file, String))
        matlab_results = matlab_data.results
        
        dataset_results["comparisons"]["matlab"] = compare_with_reference(
            julia_results, matlab_results, "MATLAB"
        )
    else
        println("MATLAB reference not available for $dataset_name")
    end
    
    # Create plots for this dataset
    create_dataset_plots(dataset_name, julia_results, 
                        allantools_available ? allantools_data.results : nothing,
                        matlab_available ? matlab_data.results : nothing)
    
    # Store results for final summary
    all_results[dataset_name] = dataset_results
    
    println("Completed processing $dataset_name")
end

# Create overall summary
create_summary_report(all_results)

println("\n" * "="^60)
println("Real dataset validation complete!")
println("="^60)
println("Check validation/ directory for plots and detailed results.")

function compare_with_reference(julia_results, reference_results, ref_name)
    """Compare Julia results with reference implementation"""
    
    comparison_data = Dict()
    
    println("  Comparing with $ref_name:")
    println("  Function    | Mean Diff | Max Diff | Min Diff | Points | Status")
    println("  " * "-"^65)
    
    for (func_name, julia_result) in julia_results
        if !haskey(reference_results, func_name)
            continue
        end
        
        # Get reference data
        if ref_name == "MATLAB"
            ref = reference_results[func_name]
            ref_tau = Vector{Float64}(ref.tau)
            ref_dev = Vector{Float64}(ref.dev)
        else  # AllanTools
            ref = reference_results[func_name]
            ref_tau = Vector{Float64}(ref.tau)
            ref_dev = Vector{Float64}(ref.dev)
        end
        
        # Find matching points
        matches = []
        for (i, jt) in enumerate(julia_result.tau)
            idx = argmin(abs.(ref_tau .- jt))
            if abs(ref_tau[idx] - jt) < 0.2 * jt  # Within 20% tolerance
                julia_val = julia_result.deviation[i]
                ref_val = ref_dev[idx]
                diff_pct = abs(julia_val - ref_val) / ref_val * 100
                push!(matches, (jt, julia_val, ref_val, diff_pct))
            end
        end
        
        if !isempty(matches)
            diff_pcts = [m[4] for m in matches]
            mean_diff = mean(diff_pcts)
            max_diff = maximum(diff_pcts)
            min_diff = minimum(diff_pcts)
            
            # Determine status
            if mean_diff < 1.0
                status = "✓ Excellent"
            elseif mean_diff < 5.0
                status = "⚠ Good"
            else
                status = "✗ Poor"
            end
            
            println(@sprintf("  %-11s | %8.2f%% | %7.2f%% | %7.2f%% | %6d | %s",
                           func_name, mean_diff, max_diff, min_diff, length(matches), status))
            
            # Store detailed comparison data
            comparison_data[func_name] = Dict(
                "matches" => matches,
                "mean_diff" => mean_diff,
                "max_diff" => max_diff,
                "min_diff" => min_diff,
                "n_points" => length(matches),
                "status" => status
            )
        else
            println(@sprintf("  %-11s | %8s | %7s | %7s | %6s | No matches",
                           func_name, "N/A", "N/A", "N/A", "0"))
        end
    end
    
    return comparison_data
end

function create_dataset_plots(dataset_name, julia_results, allantools_results, matlab_results)
    """Create comparison plots for a dataset"""
    
    println("\nCreating plots for $dataset_name...")
    
    plots_array = []
    colors = [:blue, :red, :green, :orange, :purple, :brown, :pink, :gray, :olive, :cyan, :magenta]
    
    # Create individual plots for each function
    for (i, (func_name, julia_result)) in enumerate(pairs(julia_results))
        color_idx = ((i - 1) % length(colors)) + 1
        
        p = plot(julia_result.tau, julia_result.deviation,
                marker=:circle, linewidth=2, markersize=3,
                xscale=:log10, yscale=:log10,
                xlabel="τ (s)", ylabel="Deviation",
                title=uppercase(func_name),
                label="Julia StabLab.jl",
                color=colors[color_idx], grid=true, minorgrid=true)
        
        # Add AllanTools reference if available
        if allantools_results !== nothing && haskey(allantools_results, func_name)
            ref = allantools_results[func_name]
            ref_tau = Vector{Float64}(ref.tau)
            ref_dev = Vector{Float64}(ref.dev)
            scatter!(p, ref_tau, ref_dev,
                    marker=:diamond, markersize=4,
                    label="AllanTools", color=:red, alpha=0.7)
        end
        
        # Add MATLAB reference if available
        if matlab_results !== nothing && haskey(matlab_results, func_name)
            ref = matlab_results[func_name]
            ref_tau = Vector{Float64}(ref.tau)
            ref_dev = Vector{Float64}(ref.dev)
            scatter!(p, ref_tau, ref_dev,
                    marker=:square, markersize=4,
                    label="MATLAB", color=:green, alpha=0.7)
        end
        
        push!(plots_array, p)
    end
    
    # Create combined plot
    if !isempty(plots_array)
        n_plots = length(plots_array)
        if n_plots <= 4
            layout_dims = (2, 2)
        elseif n_plots <= 6
            layout_dims = (2, 3)
        elseif n_plots <= 9
            layout_dims = (3, 3)
        else
            layout_dims = (4, 3)
        end
        
        combined_plot = plot(plots_array[1:min(12, n_plots)]...,
                           layout=layout_dims, size=(1400, 1000),
                           plot_title="StabLab.jl Validation: $dataset_name",
                           titlefontsize=16)
        
        plot_filename = "validation/stablab_validation_$(dataset_name).png"
        savefig(combined_plot, plot_filename)
        println("  Saved plot: $plot_filename")
    end
end

function create_summary_report(all_results)
    """Create a comprehensive summary report"""
    
    println("\n" * "="^70)
    println("COMPREHENSIVE VALIDATION SUMMARY")
    println("="^70)
    
    # Write detailed results to JSON
    results_file = "validation/real_dataset_validation_results.json"
    open(results_file, "w") do f
        JSON3.pretty(f, all_results)
    end
    println("Detailed results saved: $results_file")
    
    # Print summary table
    println("\nValidation Summary by Dataset:")
    println("-"^70)
    
    for (dataset_name, dataset_results) in all_results
        println("\\n$dataset_name:")
        
        # Summary of Julia results
        julia_funcs = keys(dataset_results["julia"])
        println("  Julia functions computed: $(join(sort(collect(julia_funcs)), ", "))")
        
        # Comparison summaries
        for (ref_name, comparison_data) in dataset_results["comparisons"]
            println("  vs $ref_name:")
            
            excellent = sum(1 for (_, data) in comparison_data if occursin("✓", data["status"]))
            good = sum(1 for (_, data) in comparison_data if occursin("⚠", data["status"]))
            poor = sum(1 for (_, data) in comparison_data if occursin("✗", data["status"]))
            
            total = excellent + good + poor
            if total > 0
                println("    Excellent (< 1%): $excellent/$total")
                println("    Good (< 5%): $good/$total") 
                println("    Poor (≥ 5%): $poor/$total")
            end
        end
    end
    
    println("\nGenerated validation plots:")
    for dataset_name in keys(all_results)
        plot_file = "stablab_validation_$(dataset_name).png"
        if isfile(joinpath("validation", plot_file))
            println("  ✓ $plot_file")
        end
    end
    
    # Recommendations
    println("\nRecommendations:")
    total_poor = 0
    for (dataset_name, dataset_results) in all_results
        for (ref_name, comparison_data) in dataset_results["comparisons"]
            for (func_name, data) in comparison_data
                if occursin("✗", data["status"])
                    println("  • Investigate $func_name algorithm ($(data["mean_diff"])% difference vs $ref_name on $dataset_name)")
                    total_poor += 1
                end
            end
        end
    end
    
    if total_poor == 0
        println("  ✓ All functions show good agreement with reference implementations")
    else
        println("  • Total functions needing investigation: $total_poor")
    end
end