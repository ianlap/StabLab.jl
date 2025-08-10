using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using StabLab
using Plots
using DelimitedFiles
using JSON3
using Printf
using Statistics

println("StabLab.jl vs AllanTools: 6krb25apr.txt Full Comparison")
println("="^55)

# Load the full rubidium dataset
data_file = joinpath(@__DIR__, "data", "6krb25apr.txt")
if !isfile(data_file)
    println("Error: Data file not found: $data_file")
    exit(1)
end

println("Loading full rubidium clock dataset: 6krb25apr.txt")
data_matrix = readdlm(data_file, Float64)
phase_data = vec(data_matrix[:, 2])  # Phase data is in column 2
tau0 = 1.0
N = length(phase_data)

println("Loaded $N data points")
println("Data range: [$(@sprintf("%.6f", minimum(phase_data))), $(@sprintf("%.6f", maximum(phase_data)))]")
println("Sampling interval τ₀ = $tau0 s")
println("Dataset duration: $(N * tau0) seconds")

# Generate octave-spaced m values (matching AllanTools)  
function generate_octave_m_values(N)
    max_m = N ÷ 10  # Conservative limit
    m_values = Int[]
    m = 1
    while m <= max_m
        push!(m_values, m)
        m *= 2  # Octave spacing
    end
    return m_values
end

m_values = generate_octave_m_values(N)

println("Using octave spacing: m = $m_values")
println("Tau range: $(m_values[1] * tau0) to $(m_values[end] * tau0) seconds ($(length(m_values)) points)")

# Compute StabLab.jl results
println("\n" * "="^55)
println("Computing StabLab.jl deviations...")
println("="^55)

julia_results = Dict()
computation_times = Dict()

# Functions to test (matching AllanTools)
test_functions = [
    ("adev", (data, tau0, m_list) -> adev(data, tau0, mlist=m_list)),
    ("mdev", (data, tau0, m_list) -> mdev(data, tau0, mlist=m_list)),
    ("tdev", (data, tau0, m_list) -> tdev(data, tau0, mlist=m_list)),
    ("hdev", (data, tau0, m_list) -> hdev(data, tau0, mlist=m_list)),
    ("totdev", (data, tau0, m_list) -> totdev(data, tau0, mlist=m_list)),
    ("mtotdev", (data, tau0, m_list) -> mtotdev(data, tau0, mlist=m_list)),
    ("pdev", (data, tau0, m_list) -> pdev(data, tau0, m_list=m_list))
]

for (func_name, func) in test_functions
    print("  $(rpad(func_name, 8)): ")
    
    try
        start_time = time()
        result = func(phase_data, tau0, m_values)
        elapsed = time() - start_time
        
        julia_results[func_name] = result
        computation_times[func_name] = elapsed
        
        println("✓ $(length(result.tau)) points ($(round(elapsed, digits=2))s)")
        
    catch e
        println("✗ Failed: $e")
        computation_times[func_name] = NaN
    end
end

# Load AllanTools reference
println("\n" * "="^55)
println("Loading AllanTools reference...")
println("="^55)

allantools_file = joinpath(@__DIR__, "allantools_6krb25apr_octave.json")
if !isfile(allantools_file)
    println("Error: AllanTools reference not found. Run generate_allantools_6krb25apr.py first")
    exit(1)
end

allantools_data = JSON3.read(read(allantools_file, String))
allantools_results = allantools_data.results

println("Loaded AllanTools reference with $(length(allantools_results)) functions")

# Create detailed comparison
println("\n" * "="^55)
println("DETAILED COMPARISON")
println("="^55)

comparison_summary = Dict()

for func_name in keys(julia_results)
    if !haskey(allantools_results, func_name)
        println("$func_name: No AllanTools reference available")
        continue
    end
    
    julia_result = julia_results[func_name]
    allantools_result = allantools_results[func_name]
    
    # Get reference data
    ref_tau = Vector{Float64}(allantools_result.tau)
    ref_dev = Vector{Float64}(allantools_result.dev)
    
    println("\\n$func_name comparison:")
    println("τ (s)    | StabLab.jl | AllanTools | Ratio   | Diff (%)")
    println("-"^55)
    
    differences = []
    
    # Compare point by point
    for i in 1:min(length(julia_result.tau), length(ref_tau))
        julia_tau = julia_result.tau[i]
        julia_dev = julia_result.deviation[i]
        
        # Find matching AllanTools point
        ref_idx = argmin(abs.(ref_tau .- julia_tau))
        if abs(ref_tau[ref_idx] - julia_tau) < 0.1 * julia_tau
            ref_dev_val = ref_dev[ref_idx]
            ratio = julia_dev / ref_dev_val
            diff_pct = abs(julia_dev - ref_dev_val) / ref_dev_val * 100
            
            push!(differences, diff_pct)
            
            println(@sprintf("%-8.1f | %-10.3e | %-10.3e | %-7.4f | %-7.2f%%",
                           julia_tau, julia_dev, ref_dev_val, ratio, diff_pct))
        end
    end
    
    if !isempty(differences)
        mean_diff = mean(differences)
        max_diff = maximum(differences)
        min_diff = minimum(differences)
        
        status = mean_diff < 1.0 ? "✓ Excellent" : (mean_diff < 5.0 ? "⚠ Good" : "✗ Poor")
        
        println(@sprintf("Summary: Mean=%.2f%%, Max=%.2f%%, Min=%.2f%% | %s", 
                        mean_diff, max_diff, min_diff, status))
        
        comparison_summary[func_name] = (mean_diff, max_diff, min_diff, status)
    end
end

# Create comprehensive comparison plots
println("\n" * "="^55)
println("Creating comparison plots...")
println("="^55)

plot_array = []
colors = [:blue, :red, :green, :orange, :purple, :brown, :pink]

for (i, func_name) in enumerate(keys(julia_results))
    if !haskey(allantools_results, func_name)
        continue
    end
    
    julia_result = julia_results[func_name]
    allantools_result = allantools_results[func_name]
    
    # Get AllanTools reference data
    ref_tau = Vector{Float64}(allantools_result.tau)
    ref_dev = Vector{Float64}(allantools_result.dev)
    
    color = colors[min(i, length(colors))]
    
    # Create comparison plot
    p = plot(julia_result.tau, julia_result.deviation,
            marker=:circle, linewidth=2, markersize=4,
            xscale=:log10, yscale=:log10,
            xlabel="τ (s)", ylabel="Deviation",
            title="$(uppercase(func_name))\\n$(get(comparison_summary, func_name, ("", "", "", ""))[4])",
            label="StabLab.jl",
            color=color, grid=true, minorgrid=true)
    
    # Add AllanTools reference
    scatter!(p, ref_tau, ref_dev,
            marker=:diamond, markersize=6,
            label="AllanTools",
            color=:black, markerstrokewidth=1, alpha=0.7)
    
    # Add difference percentage if available
    if haskey(comparison_summary, func_name)
        mean_diff = comparison_summary[func_name][1]
        annotate!(p, [(0.02, 0.02, text("Avg: $(round(mean_diff, digits=2))%", 8, :left, :bottom))])
    end
    
    push!(plot_array, p)
end

# Create combined comparison plot
combined_plot = plot(plot_array...,
                    layout=(3,3), size=(1600, 1200),
                    plot_title="StabLab.jl vs AllanTools: 6krb25apr.txt (Rubidium Clock)\\nFull Dataset with Octave Spacing",
                    titlefontsize=16, margin=5Plots.mm)

# Save the comparison plot
output_file = "validation/stablab_vs_allantools_6krb25apr_full.png"
savefig(combined_plot, output_file)
println("Saved comprehensive comparison plot: $output_file")

# Create accuracy summary plot
accuracy_data = []
func_names_ordered = []

for (func_name, (mean_diff, max_diff, min_diff, status)) in comparison_summary
    push!(accuracy_data, mean_diff)
    push!(func_names_ordered, uppercase(func_name))
end

if !isempty(accuracy_data)
    accuracy_plot = bar(func_names_ordered, accuracy_data,
                       title="StabLab.jl vs AllanTools Accuracy\\n6krb25apr.txt (Mean Percentage Difference)",
                       xlabel="Deviation Function", ylabel="Mean Difference (%)",
                       color=:lightblue, alpha=0.7)
    
    # Add horizontal lines for thresholds
    hline!(accuracy_plot, [1.0], color=:green, linestyle=:dash, linewidth=2, label="1% (Excellent)")
    hline!(accuracy_plot, [5.0], color=:orange, linestyle=:dash, linewidth=2, label="5% (Good)")
    
    ylims!(accuracy_plot, (0, max(maximum(accuracy_data) * 1.1, 10)))
    
    savefig(accuracy_plot, "validation/stablab_accuracy_6krb25apr.png")
    println("Saved accuracy summary plot: validation/stablab_accuracy_6krb25apr.png")
end

# Final summary
println("\n" * "="^70)
println("FINAL COMPARISON SUMMARY")
println("="^70)

println("Dataset: 6krb25apr.txt (Full rubidium clock dataset)")
println("Points analyzed: $N")
println("Functions compared: $(length(comparison_summary))")

println("\\nAccuracy Summary:")
excellent = sum(1 for (_, (mean_diff, _, _, _)) in comparison_summary if mean_diff < 1.0)
good = sum(1 for (_, (mean_diff, _, _, _)) in comparison_summary if 1.0 <= mean_diff < 5.0)
poor = sum(1 for (_, (mean_diff, _, _, _)) in comparison_summary if mean_diff >= 5.0)

total = excellent + good + poor
println("  Excellent (< 1%):  $excellent/$total functions")
println("  Good (1-5%):       $good/$total functions")
println("  Poor (≥ 5%):       $poor/$total functions")

println("\\nGenerated files:")
println("  $output_file")
println("  validation/stablab_accuracy_6krb25apr.png")

if poor > 0
    println("\\n⚠ Functions needing investigation:")
    for (func_name, (mean_diff, _, _, status)) in comparison_summary
        if mean_diff >= 5.0
            println("  • $(uppercase(func_name)): $(round(mean_diff, digits=2))% mean difference")
        end
    end
else
    println("\\n✓ All functions show excellent agreement with AllanTools!")
end

println("\\nComparison complete! Review the plots to see detailed algorithm validation.")