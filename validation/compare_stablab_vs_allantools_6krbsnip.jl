using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using StabLab
using Plots
using DelimitedFiles
using JSON3
using Printf
using Statistics

println("StabLab.jl vs AllanTools: 6krbsnip.txt Fast Validation")
println("="^55)

# Load the 100k point rubidium dataset
data_file = joinpath(@__DIR__, "data", "6krbsnip.txt")
if !isfile(data_file)
    println("Error: Data file not found: $data_file")
    exit(1)
end

println("Loading rubidium clock dataset: 6krbsnip.txt")
data_matrix = readdlm(data_file, Float64)
phase_data = vec(data_matrix[:, 2])  # Phase data is in column 2
tau0 = 1.0
N = length(phase_data)

println("Loaded $N data points")
min_val = minimum(phase_data)
max_val = maximum(phase_data)
println("Data range: [$min_val, $max_val]")
println("Sampling interval τ₀ = $tau0 s")
duration = N * tau0
println("Dataset duration: $duration seconds")

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
tau_min = m_values[1] * tau0
tau_max = m_values[end] * tau0
n_points = length(m_values)
println("Tau range: $tau_min to $tau_max seconds ($n_points points)")

# Compute StabLab.jl results with timing
println("\n" * "="^55)
println("Computing StabLab.jl deviations with timing...")
println("="^55)

julia_results = Dict()
julia_timing = Dict()

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

julia_total_start = time()

for (func_name, func) in test_functions
    print("  $(rpad(uppercase(func_name), 8)): ")
    
    try
        start_time = time()
        result = func(phase_data, tau0, m_values)
        elapsed = time() - start_time
        
        julia_results[func_name] = result
        julia_timing[func_name] = elapsed
        
        n_points_computed = length(result.tau)
        rate = n_points_computed / elapsed
        println("✓ $n_points_computed points ($(round(elapsed, digits=2))s, $(round(rate, digits=1)) pts/s)")
        
    catch e
        julia_timing[func_name] = NaN
        println("✗ Failed: $e")
    end
end

julia_total_elapsed = time() - julia_total_start
println("\\nTotal StabLab.jl computation time: $(round(julia_total_elapsed, digits=2))s")

# Load AllanTools reference
println("\\n" * "="^55)
println("Loading AllanTools reference...")
println("="^55)

allantools_file = joinpath(@__DIR__, "allantools_6krbsnip_octave.json")
if !isfile(allantools_file)
    println("Error: AllanTools reference not found. Run generate_allantools_6krbsnip.py first")
    exit(1)
end

allantools_data = JSON3.read(read(allantools_file, String))
allantools_results = allantools_data.results
allantools_timing = allantools_data.metadata.computation_time.function_times
allantools_total = allantools_data.metadata.computation_time.total_seconds

println("Loaded AllanTools reference with $(length(allantools_results)) functions")
println("AllanTools total computation time: $(round(allantools_total, digits=2))s")

# Performance comparison
println("\\n" * "="^55)
println("PERFORMANCE COMPARISON")
println("="^55)

println("$(rpad("Function", 10)) | $(rpad("StabLab.jl", 12)) | $(rpad("AllanTools", 12)) | $(rpad("Speedup", 10))")
println("-"^60)

speedup_factors = []
for func_name in keys(julia_results)
    if haskey(allantools_timing, func_name)
        julia_time = julia_timing[func_name]
        allantools_time = allantools_timing[func_name]
        speedup = allantools_time / julia_time
        push!(speedup_factors, speedup)
        
        julia_str = "$(round(julia_time, digits=2))s"
        allantools_str = "$(round(allantools_time, digits=2))s"
        speedup_str = "$(round(speedup, digits=2))x"
        
        println("$(rpad(uppercase(func_name), 10)) | $(rpad(julia_str, 12)) | $(rpad(allantools_str, 12)) | $(rpad(speedup_str, 10))")
    end
end

println("-"^60)
overall_speedup = allantools_total / julia_total_elapsed
julia_total_str = "$(round(julia_total_elapsed, digits=2))s"
allantools_total_str = "$(round(allantools_total, digits=2))s"
overall_speedup_str = "$(round(overall_speedup, digits=2))x"
println("$(rpad("TOTAL", 10)) | $(rpad(julia_total_str, 12)) | $(rpad(allantools_total_str, 12)) | $(rpad(overall_speedup_str, 10))")

if !isempty(speedup_factors)
    avg_speedup = mean(speedup_factors)
    println("\\nAverage function speedup: $(round(avg_speedup, digits=2))x")
    println("Overall pipeline speedup: $(round(overall_speedup, digits=2))x")
end

# Create detailed comparison
println("\\n" * "="^55)
println("DETAILED ACCURACY COMPARISON")
println("="^55)

comparison_summary = Dict()

for func_name in keys(julia_results)
    if !haskey(allantools_results, func_name)
        println("$func_name: No AllanTools reference available")
        continue
    end
    
    println("\\n=== DEBUG: Processing $func_name ===")
    
    julia_result = julia_results[func_name]
    allantools_result = allantools_results[func_name]
    
    # Get reference data
    ref_tau = Vector{Float64}(allantools_result.tau)
    ref_dev = Vector{Float64}(allantools_result.dev)
    
    println("Julia points: $(length(julia_result.tau)), AllanTools points: $(length(ref_tau))")
    println("Julia tau range: $(julia_result.tau[1]) to $(julia_result.tau[end])")
    println("AllanTools tau range: $(ref_tau[1]) to $(ref_tau[end])")
    
    println("\\n$(uppercase(func_name)) comparison:")
    println("τ (s)    | StabLab.jl | AllanTools | Ratio   | Diff (%)")
    println("-"^55)
    
    differences = []
    
    # Compare point by point
    min_length = min(length(julia_result.tau), length(ref_tau))
    for i in 1:min_length
        julia_tau = julia_result.tau[i]
        julia_dev = julia_result.deviation[i]
        
        # Find matching AllanTools point
        ref_idx = argmin(abs.(ref_tau .- julia_tau))
        tau_tolerance = 0.1 * julia_tau
        if abs(ref_tau[ref_idx] - julia_tau) < tau_tolerance
            ref_dev_val = ref_dev[ref_idx]
            ratio = julia_dev / ref_dev_val
            diff_pct = abs(julia_dev - ref_dev_val) / ref_dev_val * 100
            
            push!(differences, diff_pct)
            
            tau_str = @sprintf("%.1f", julia_tau)
            julia_str = @sprintf("%.3e", julia_dev)
            ref_str = @sprintf("%.3e", ref_dev_val)
            ratio_str = @sprintf("%.4f", ratio)
            diff_str = @sprintf("%.2f%%", diff_pct)
            
            println("$(rpad(tau_str, 8)) | $(rpad(julia_str, 10)) | $(rpad(ref_str, 10)) | $(rpad(ratio_str, 7)) | $diff_str")
        end
    end
    
    println("Found $(length(differences)) matching tau points")
    
    if !isempty(differences)
        mean_diff = mean(differences)
        max_diff = maximum(differences)
        min_diff = minimum(differences)
        
        status = mean_diff < 1.0 ? "✓ Excellent" : (mean_diff < 5.0 ? "⚠ Good" : "✗ Poor")
        
        summary_str = @sprintf("Summary: Mean=%.2f%%, Max=%.2f%%, Min=%.2f%% | %s", 
                              mean_diff, max_diff, min_diff, status)
        println(summary_str)
        
        comparison_summary[func_name] = (mean_diff, max_diff, min_diff, status)
        println("Added $func_name to comparison_summary")
    else
        println("WARNING: No matching tau points found for $func_name!")
    end
end

# Create comprehensive comparison plots
println("\\n" * "="^55)
println("Creating comparison plots...")
println("comparison_summary has $(length(comparison_summary)) entries")
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
    title_str = "$(uppercase(func_name))"
    if haskey(comparison_summary, func_name)
        status = comparison_summary[func_name][4]
        title_str *= "\\n$status"
    else
        title_str *= "\\n(Comparison data unavailable)"
    end
    
    p = plot(julia_result.tau, julia_result.deviation,
            marker=:circle, linewidth=2, markersize=4,
            xscale=:log10, yscale=:log10,
            xlabel="τ (s)", ylabel="Deviation",
            title=title_str,
            label="StabLab.jl",
            color=color, grid=true, minorgrid=true)
    
    # Add AllanTools reference
    scatter!(p, ref_tau, ref_dev,
            marker=:diamond, markersize=6,
            label="AllanTools",
            color=:black, markerstrokewidth=1, alpha=0.7)
    
    # Add accuracy and timing annotations
    if haskey(comparison_summary, func_name) && haskey(allantools_timing, func_name)
        mean_diff = comparison_summary[func_name][1]
        julia_time = julia_timing[func_name]
        allantools_time = allantools_timing[func_name]
        speedup = allantools_time / julia_time
        
        annotation_text = "Acc: $(round(mean_diff, digits=2))%\\nSpeedup: $(round(speedup, digits=1))x"
        annotate!(p, [(0.02, 0.02, text(annotation_text, 8, :left, :bottom))])
    elseif haskey(allantools_timing, func_name)
        julia_time = julia_timing[func_name]
        allantools_time = allantools_timing[func_name]
        speedup = allantools_time / julia_time
        
        annotation_text = "Speedup: $(round(speedup, digits=1))x"
        annotate!(p, [(0.02, 0.02, text(annotation_text, 8, :left, :bottom))])
    end
    
    push!(plot_array, p)
end

# Create combined comparison plot
combined_plot = plot(plot_array...,
                    layout=(3,3), size=(1600, 1200),
                    plot_title="StabLab.jl vs AllanTools: 6krbsnip.txt (Rubidium Clock, 100k points)\\nFast Validation with Performance Metrics",
                    titlefontsize=16, margin=5Plots.mm)

# Save the comparison plot
output_file = "stablab_vs_allantools_6krbsnip_fast.png"
savefig(combined_plot, output_file)
println("Saved comprehensive comparison plot: $output_file")

# Create performance summary plot
performance_data = []
func_names_ordered = []

for func_name in keys(julia_results)
    if haskey(allantools_timing, func_name)
        julia_time = julia_timing[func_name]
        allantools_time = allantools_timing[func_name]
        speedup = allantools_time / julia_time
        push!(performance_data, speedup)
        push!(func_names_ordered, uppercase(func_name))
    end
end

if !isempty(performance_data)
    performance_plot = bar(func_names_ordered, performance_data,
                          title="StabLab.jl Performance vs AllanTools\\n6krbsnip.txt Speedup Factors",
                          xlabel="Deviation Function", ylabel="Speedup Factor",
                          color=:lightgreen, alpha=0.7)
    
    # Add horizontal line at 1x (equal performance)
    hline!(performance_plot, [1.0], color=:red, linestyle=:dash, linewidth=2, label="Equal Performance")
    
    # Add overall speedup line
    hline!(performance_plot, [overall_speedup], color=:blue, linestyle=:dash, linewidth=2, 
           label="Overall Speedup ($(round(overall_speedup, digits=1))x)")
    
    ylims!(performance_plot, (0, max(maximum(performance_data) * 1.1, 2)))
    
    savefig(performance_plot, "stablab_performance_6krbsnip.png")
    println("Saved performance summary plot: stablab_performance_6krbsnip.png")
else
    println("No performance data available for plotting")
end

# Final summary
println("\\n" * "="^70)
println("FINAL VALIDATION SUMMARY")
println("="^70)

println("Dataset: 6krbsnip.txt (Rubidium clock, 100k points)")
println("Functions compared: $(length(comparison_summary))")

println("\\nAccuracy Summary:")
excellent = sum(1 for (_, (mean_diff, _, _, _)) in comparison_summary if mean_diff < 1.0; init=0)
good = sum(1 for (_, (mean_diff, _, _, _)) in comparison_summary if 1.0 <= mean_diff < 5.0; init=0)
poor = sum(1 for (_, (mean_diff, _, _, _)) in comparison_summary if mean_diff >= 5.0; init=0)

total_funcs = excellent + good + poor
println("  Excellent (< 1%):  $excellent/$total_funcs functions")
println("  Good (1-5%):       $good/$total_funcs functions")
println("  Poor (≥ 5%):       $poor/$total_funcs functions")

println("\\nPerformance Summary:")
println("  StabLab.jl total time: $(round(julia_total_elapsed, digits=2))s")
println("  AllanTools total time: $(round(allantools_total, digits=2))s")
println("  Overall speedup: $(round(overall_speedup, digits=2))x")

if !isempty(speedup_factors)
    avg_speedup = mean(speedup_factors)
    println("  Average function speedup: $(round(avg_speedup, digits=2))x")
end

println("\\nGenerated files:")
println("  $output_file")
println("  stablab_performance_6krbsnip.png")

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

println("\\nFast validation complete! StabLab.jl shows $(round(overall_speedup, digits=1))x speedup over AllanTools.")