# Mega Benchmark: StabLab.jl vs AllanTools vs MATLAB
# Tests ADEV, MDEV, HDEV with 10^7 data points across 30 datasets

using Pkg
Pkg.activate(".")

using StabLab
using NPZ
using Random
using Statistics
using Plots

function generate_test_datasets(N=10_000_000, num_datasets=30, tau0=1.0)
    # Generate multiple test datasets for benchmarking
    println("Generating $num_datasets datasets of $(N÷1_000_000)M samples each...")
    
    datasets = Vector{Vector{Float64}}()
    
    for i in 1:num_datasets
        # Use different seeds for each dataset (matching Python)
        Random.seed!(42 + i - 1)  # -1 because Julia is 1-indexed
        phase_data = cumsum(randn(N)) * 1e-9
        push!(datasets, phase_data)
        
        if i == 1
            println("  Dataset 1: range [$(minimum(phase_data):.2e), $(maximum(phase_data):.2e)]")
        end
    end
    
    return datasets, tau0
end

function benchmark_function(func, datasets, tau0, func_name, max_tau_points=20)
    # Benchmark a single function across all datasets
    println("\\n=== Benchmarking $(uppercase(func_name)) ===")
    
    N = length(datasets[1])
    # Generate m_list (octave-spaced) - matching Python
    max_m = N ÷ 4
    m_list = Int[]
    m = 1
    while m <= max_m && length(m_list) < max_tau_points
        push!(m_list, m)
        m *= 2
    end
    
    times = Float64[]
    first_values = Float64[]
    all_results = nothing
    
    for (i, phase_data) in enumerate(datasets)
        print("  Dataset $i/$(length(datasets)): ")
        flush(stdout)
        
        start_time = time()
        try
            result = func(phase_data, tau0, mlist=m_list)
            elapsed = time() - start_time
            
            push!(times, elapsed)
            push!(first_values, result.deviation[1])
            
            if i == 1  # Save first result for validation
                all_results = result
            end
            
            println("$(elapsed:.2f)s (dev[0]=$(result.deviation[1]:.3e))")
            
        catch e
            println("FAILED: $e")
            return nothing
        end
    end
    
    # Statistics
    mean_time = mean(times)
    std_time = length(times) > 1 ? std(times) : 0.0
    mean_first_val = mean(first_values)
    std_first_val = length(first_values) > 1 ? std(first_values) : 0.0
    
    println("  Results:")
    println("    Mean time: $(mean_time:.3f) ± $(std_time:.3f)s")
    println("    Total time: $(sum(times):.2f)s")
    println("    First value: $(mean_first_val:.6e) ± $(std_first_val:.2e)")
    println("    Throughput: $(N * length(datasets) / sum(times) / 1e6:.2f) Msamples/sec")
    
    return Dict(
        "times" => times,
        "mean_time" => mean_time,
        "std_time" => std_time,
        "total_time" => sum(times),
        "first_values" => first_values,
        "mean_first_val" => mean_first_val,
        "std_first_val" => std_first_val,
        "results" => all_results,
        "tau_points" => length(all_results.tau)
    )
end

function save_output_and_plots(results, total_time, N, num_datasets)
    # Save output to text file and create performance plots
    
    # Save text output
    open("/tmp/julia_mega_benchmark_results.txt", "w") do f
        println(f, "🚀 MEGA BENCHMARK: StabLab.jl (Julia)")
        println(f, "=" ^ 60)
        println(f, "Target: 30 datasets × 10^7 samples = 3 × 10^8 total samples")
        println(f, "Functions: ADEV, MDEV, HDEV\\n")
        
        println(f, "📊 Dataset info:")
        println(f, "  - Sample count: $(N÷1_000_000)M per dataset")
        println(f, "  - Number of datasets: $num_datasets")
        println(f, "  - Total samples: $((N * num_datasets)÷1_000_000)M")
        println(f, "  - Memory per dataset: ~$(N * 8 / 1024^2:.1f) MB")
        println(f, "  - Total memory: ~$(N * num_datasets * 8 / 1024^3:.2f) GB\\n")
        
        println(f, "🏁 JULIA STABLAB SUMMARY")
        println(f, "=" ^ 60)
        println(f, "Total execution time: $(total_time:.2f)s ($(total_time/60:.1f) min)\\n")
        
        grand_total_time = 0.0
        functions = ["adev", "mdev", "hdev"]
        for func_name in functions
            result = results[func_name]
            grand_total_time += result["total_time"]
            println(f, "$(uppercase(func_name)): $(result["mean_time"]:6.2f) ± $(result["std_time"]:5.2f)s per dataset, " *
                     "$(result["total_time"]:7.1f)s total, $(result["tau_points"]:2d) tau points")
        end
        
        overall_throughput = (N * num_datasets * length(functions)) / grand_total_time / 1e6
        println(f, "Overall throughput: $(overall_throughput:.2f) Msamples/sec")
    end
    
    println("💾 Text results saved to /tmp/julia_mega_benchmark_results.txt")
    
    # Create performance plots
    functions = ["adev", "mdev", "hdev"]
    
    # Plot 1: Timing distribution
    p1 = plot(title="Timing Distribution Across 30 Datasets", 
              xlabel="Time per dataset (s)", ylabel="Count")
    for func_name in functions
        times = results[func_name]["times"]
        histogram!(p1, times, alpha=0.7, label=uppercase(func_name), bins=10)
    end
    
    # Plot 2: Mean performance comparison
    mean_times = [results[func]["mean_time"] for func in functions]
    std_times = [results[func]["std_time"] for func in functions]
    
    p2 = bar(functions, mean_times, yerr=std_times, 
             title="Mean Performance ± Std Dev",
             ylabel="Mean time per dataset (s)",
             alpha=0.8, color=[:blue :orange :green])
    
    # Plot 3: First value consistency  
    p3 = plot(title="First Value Distribution (Consistency Check)",
              xlabel="First deviation value", ylabel="Count")
    for func_name in functions
        first_vals = results[func_name]["first_values"]
        histogram!(p3, first_vals, alpha=0.7, label=uppercase(func_name), bins=15)
    end
    
    # Combine plots
    combined_plot = plot(p1, p2, p3, layout=(1,3), size=(1500, 400))
    savefig(combined_plot, "/tmp/julia_mega_benchmark_plots.png")
    
    println("📊 Performance plots saved to /tmp/julia_mega_benchmark_plots.png")
end

function compare_with_python_results(results)
    # Load and compare with Python results
    try
        python_results = npzread("/tmp/python_mega_results.npz")
        
        println("\\n=== VALIDATION: Julia vs Python ===")
        println("Function | Julia Mean | Python Mean | Speedup | Value Match")
        println("---------|------------|-------------|---------|------------")
        
        functions = ["adev", "mdev", "hdev"]
        total_julia = 0.0
        total_python = 0.0
        
        for func_name in functions
            julia_time = results[func_name]["mean_time"]
            python_time = python_results["$(func_name)_mean_time"]
            speedup = python_time / julia_time
            
            julia_val = results[func_name]["mean_first_val"]
            python_val = python_results["$(func_name)_mean_first_val"]
            rel_error = abs(julia_val - python_val) / python_val * 100
            
            match_status = rel_error < 1.0 ? "✓ MATCH" : "⚠ DIFF"
            
            println("$(rpad(uppercase(func_name), 8)) | $(rpad(string(round(julia_time, digits=3)), 10)) | " * 
                   "$(rpad(string(round(python_time, digits=3)), 11)) | " *
                   "$(rpad(string(round(speedup, digits=2)) * "x", 7)) | $match_status")
            
            total_julia += julia_time
            total_python += python_time
        end
        
        overall_speedup = total_python / total_julia
        println("---------|------------|-------------|---------|------------")
        println("$(rpad("OVERALL", 8)) | $(rpad(string(round(total_julia, digits=2)), 10)) | " * 
               "$(rpad(string(round(total_python, digits=2)), 11)) | " *
               "$(string(round(overall_speedup, digits=2)) * "x") | ")
        
        if overall_speedup > 1.0
            println("\\n🚀 Julia StabLab.jl is $(round(overall_speedup, digits=2))x faster than Python AllanTools!")
        else
            println("\\n⚠️  Python AllanTools is $(round(1/overall_speedup, digits=2))x faster than Julia StabLab.jl")
        end
        
    catch e
        println("\\n⚠️  Could not load Python results for comparison: $e")
    end
end

function main()
    # Save output to both console and log file
    original_stdout = stdout
    log_file = open("/tmp/julia_mega_benchmark_log.txt", "w")
    
    # Custom function to write to both outputs
    function dual_println(msg="")
        println(original_stdout, msg)
        println(log_file, msg)
        flush(log_file)
    end
    
    dual_println("🚀 MEGA BENCHMARK: StabLab.jl (Julia)")
    dual_println("=" ^ 60)
    dual_println("Target: 30 datasets × 10^7 samples = 3 × 10^8 total samples")
    dual_println("Functions: ADEV, MDEV, HDEV")
    dual_println()
    
    # Generate datasets
    N = 10_000_000
    num_datasets = 30
    datasets, tau0 = generate_test_datasets(N, num_datasets, 1.0)
    
    dual_println("📊 Dataset info:")
    dual_println("  - Sample count: $(N÷1_000_000)M per dataset")
    dual_println("  - Number of datasets: $num_datasets")  
    dual_println("  - Total samples: $((N * num_datasets)÷1_000_000)M")
    dual_println("  - Memory per dataset: ~$(N * 8 / 1024^2:.1f) MB")
    dual_println("  - Total memory: ~$(N * num_datasets * 8 / 1024^3:.2f) GB")
    
    # Benchmark functions
    functions = [
        ("adev", adev),
        ("mdev", mdev), 
        ("hdev", hdev)
    ]
    results = Dict{String, Any}()
    
    total_start_time = time()
    
    for (func_name, func) in functions
        result = benchmark_function(func, datasets, tau0, func_name)
        if result === nothing
            dual_println("❌ $func_name failed!")
            close(log_file)
            return
        end
        results[func_name] = result
    end
    
    total_time = time() - total_start_time
    
    # Summary
    dual_println("\\n🏁 JULIA STABLAB SUMMARY")
    dual_println("=" ^ 60)
    dual_println("Total execution time: $(total_time:.2f)s ($(total_time/60:.1f) min)")
    
    grand_total_time = 0.0
    for func_name in ["adev", "mdev", "hdev"]
        result = results[func_name]
        grand_total_time += result["total_time"]
        dual_println("$(uppercase(func_name)):  $(result["mean_time"]:6.2f) ± $(result["std_time"]:5.2f)s per dataset, " *
                    "$(result["total_time"]:7.1f)s total, $(result["tau_points"]:2d) tau points")
    end
    
    overall_throughput = (N * num_datasets * 3) / grand_total_time / 1e6
    dual_println("Overall throughput: $(overall_throughput:.2f) Msamples/sec")
    
    close(log_file)
    
    # Save results and create plots
    save_output_and_plots(results, total_time, N, num_datasets)
    
    # Compare with Python if available
    compare_with_python_results(results)
    
    # Save validation dataset (first dataset only)
    first_dataset = datasets[1]
    save_dict = Dict(
        "phase_data" => first_dataset,
        "tau0" => tau0,
        "N" => N
    )
    
    for (func_name, _) in functions
        result = results[func_name]["results"]
        save_dict["$(func_name)_tau"] = result.tau
        save_dict["$(func_name)_dev"] = result.deviation
        save_dict["$(func_name)_mean_time"] = results[func_name]["mean_time"]
        save_dict["$(func_name)_total_time"] = results[func_name]["total_time"]
    end
    
    npzwrite("/tmp/julia_mega_results.npz", save_dict)
    
    println("\\n💾 Results saved to /tmp/julia_mega_results.npz")
    println("🎯 Ready for MATLAB comparison!")
end

# Run benchmark
main()