# Simplified Benchmark: oadev, mdev, ohdev
# 20 datasets x 1M samples with EDF and CI metrics

using Pkg
Pkg.activate("..")

using StabLab
using Random
using Statistics

println("🚀 SIMPLIFIED BENCHMARK: StabLab.jl")
println("=" ^ 50)
println("Functions: OADEV (adev), MDEV, OHDEV (hdev)")
println("Data: 20 datasets × 1M samples = 20M total samples")
println()

function benchmark_with_ci(func, func_name, datasets, tau0)
    println("=== Benchmarking $(uppercase(func_name)) ===")
    
    times = Float64[]
    ci_times = Float64[]
    first_values = Float64[]
    edf_values = Float64[]
    ci_widths = Float64[]
    
    for (i, phase_data) in enumerate(datasets)
        print("  Dataset $i/$(length(datasets)): ")
        
        # Time basic deviation calculation
        start_time = time()
        result = func(phase_data, tau0)
        dev_time = time() - start_time
        
        # Time confidence interval calculation  
        ci_start = time()
        result_with_ci = compute_ci(result, 0.683)
        ci_time = time() - ci_start
        
        total_time = dev_time + ci_time
        push!(times, total_time)
        push!(ci_times, ci_time)
        push!(first_values, result.deviation[1])
        push!(edf_values, result_with_ci.edf[1])
        push!(ci_widths, result_with_ci.ci[1,2] - result_with_ci.ci[1,1])
        
        println("$(total_time:.2f)s (dev=$(round(result.deviation[1]*1e9, digits=1))ns, " *
               "edf=$(round(result_with_ci.edf[1], digits=0)), ci=$(round(ci_time*1000, digits=1))ms)")
    end
    
    # Statistics
    mean_time = mean(times)
    mean_ci_time = mean(ci_times)
    mean_first_val = mean(first_values)
    mean_edf = mean(edf_values)
    mean_ci_width = mean(ci_widths)
    
    println("  Results:")
    println("    Mean time: $(round(mean_time, digits=3))s (dev + CI)")
    println("    CI overhead: $(round(mean_ci_time*1000, digits=1))ms avg")
    println("    Total time: $(round(sum(times), digits=1))s")
    println("    First value: $(round(mean_first_val*1e9, digits=2))ns ± $(round(std(first_values)*1e9, digits=2))ns")
    println("    Mean EDF: $(round(mean_edf, digits=0))")
    println("    Mean CI width: $(round(mean_ci_width*1e9, digits=2))ns")
    println("    Throughput: $(round(length(datasets) * length(datasets[1]) / sum(times) / 1e6, digits=2)) Msamples/sec")
    println()
    
    return Dict(
        "times" => times,
        "ci_times" => ci_times,
        "mean_time" => mean_time,
        "mean_ci_time" => mean_ci_time,
        "total_time" => sum(times),
        "first_values" => first_values,
        "mean_first_val" => mean_first_val,
        "edf_values" => edf_values,
        "mean_edf" => mean_edf,
        "ci_widths" => ci_widths,
        "mean_ci_width" => mean_ci_width,
        "tau_points" => length(result.tau)
    )
end

function main()
    # Generate test datasets
    Random.seed!(42)
    N = 1_000_000  # 1M samples per dataset
    num_datasets = 20
    tau0 = 1.0
    
    println("📊 Generating datasets:")
    println("  - Sample count: $(N÷1000)k per dataset")
    println("  - Number of datasets: $num_datasets")
    println("  - Total samples: $(N * num_datasets ÷ 1_000_000)M")
    println("  - Memory per dataset: ~$(N * 8 / 1024^2:.1f) MB")
    println("  - Total memory: ~$(N * num_datasets * 8 / 1024^3:.2f) GB")
    println()
    
    # Generate White FM datasets
    datasets = []
    for i in 1:num_datasets
        Random.seed!(42 + i)  # Different seed for each dataset
        phase_data = cumsum(randn(N)) * 1e-9
        push!(datasets, phase_data)
    end
    
    println("Generated $num_datasets datasets of White FM noise")
    println("Phase noise level: ~$(round(std(datasets[1]) * 1e9, digits=1)) ns RMS")
    println()
    
    # Benchmark functions
    functions = [
        (adev, "oadev"),   # Our adev is overlapping Allan deviation
        (mdev, "mdev"),    # Modified Allan deviation
        (hdev, "ohdev")    # Our hdev is overlapping Hadamard deviation
    ]
    
    results = Dict{String, Any}()
    total_start_time = time()
    
    for (func, func_name) in functions
        result = benchmark_with_ci(func, func_name, datasets, tau0)
        results[func_name] = result
    end
    
    total_time = time() - total_start_time
    
    # Summary
    println("🏁 BENCHMARK SUMMARY")
    println("=" ^ 50)
    println("Total execution time: $(round(total_time, digits=1))s ($(round(total_time/60, digits=1)) min)")
    println()
    
    # Performance comparison
    println("Function | Dev Time | CI Time | Total  | EDF   | CI Width | Throughput")
    println("---------|----------|---------|--------|-------|----------|------------")
    
    for func_name in ["oadev", "mdev", "ohdev"]
        result = results[func_name]
        dev_time = result["mean_time"] - result["mean_ci_time"]
        ci_time = result["mean_ci_time"]
        total_time = result["mean_time"]
        edf = result["mean_edf"]
        ci_width = result["mean_ci_width"] * 1e9
        throughput = N * num_datasets / result["total_time"] / 1e6
        
        println("$(rpad(uppercase(func_name), 8)) | " *
               "$(rpad(string(round(dev_time, digits=3)), 8)) | " *
               "$(rpad(string(round(ci_time*1000, digits=1)) * "ms", 7)) | " *
               "$(rpad(string(round(total_time, digits=3)), 6)) | " *
               "$(rpad(string(round(edf, digits=0)), 5)) | " *
               "$(rpad(string(round(ci_width, digits=1)) * "ns", 8)) | " *
               "$(round(throughput, digits=1)) Msmp/s")
    end
    
    # Overall performance
    grand_total_time = sum([results[func_name]["total_time"] for func_name in ["oadev", "mdev", "ohdev"]])
    overall_throughput = (N * num_datasets * 3) / grand_total_time / 1e6
    
    println("---------|----------|---------|--------|-------|----------|------------")
    println("OVERALL  | -        | -       | $(rpad(string(round(grand_total_time, digits=1)), 6)) | -     | -        | $(round(overall_throughput, digits=1)) Msmp/s")
    
    println("\n✅ StabLab.jl Performance:")
    println("  • All 3 functions completed successfully")
    println("  • Professional EDF-based confidence intervals")
    println("  • Chi-squared statistical bounds")
    println("  • Overall throughput: $(round(overall_throughput, digits=1)) Msamples/sec")
    println("  • Ready for production frequency stability analysis")
    
    return results
end

# Run the benchmark
if abspath(PROGRAM_FILE) == @__FILE__
    results = main()
end