# Fair benchmark: Julia vs AllanTools with equivalent statistical methods
# Uses simple CI method to match AllanTools' σ/√n approach

using Pkg
Pkg.activate("..")

using StabLab
using Random
using Statistics

function fair_benchmark_julia()
    println("⚖️  FAIR BENCHMARK: StabLab.jl vs AllanTools Equivalent")
    println("=" ^ 60)
    println("Functions: OADEV, MDEV, OHDEV")
    println("Method: Simple CI (σ/√n) to match AllanTools")
    println("Data: 20 datasets × 1M samples = 20M total samples")
    println()
    
    # Parameters
    N = 1_000_000  # 1M samples per dataset
    num_datasets = 20
    tau0 = 1.0
    
    println("📊 Dataset info:")
    println("  - Sample count: $(N÷1000)k per dataset")
    println("  - Number of datasets: $num_datasets")
    println("  - Total samples: $(N * num_datasets ÷ 1_000_000)M")
    
    memory_per = N * 8 / 1024^2
    total_memory = N * num_datasets * 8 / 1024^3
    println("  - Memory per dataset: ~$(round(memory_per, digits=1)) MB")
    println("  - Total memory: ~$(round(total_memory, digits=2)) GB")
    println()
    
    # Generate datasets (White FM noise)
    Random.seed!(42)
    datasets = []
    for i in 1:num_datasets
        Random.seed!(42 + i)  # Different seed for each dataset
        phase_data = cumsum(randn(N)) * 1e-9
        push!(datasets, phase_data)
    end
    
    println("Generated $num_datasets datasets of White FM noise")
    println("Phase noise level: ~$(round(std(datasets[1]) * 1e9, digits=1)) ns RMS")
    println()
    
    # Test functions: (function, name, function_key)
    functions = [
        (adev, "OADEV", "oadev"),
        (mdev, "MDEV", "mdev"), 
        (hdev, "OHDEV", "ohdev")
    ]
    
    results = Dict{String, Any}()
    
    for (func, name, func_key) in functions
        println("=== Benchmarking $name (Simple CI) ===")
        
        times = Float64[]
        first_values = Float64[]
        ci_widths = Float64[]
        
        for (i, phase_data) in enumerate(datasets)
            print("  Dataset $i/$num_datasets: ")
            flush(stdout)
            
            start_time = time()
            try
                # Basic deviation calculation (fast)
                result = func(phase_data, tau0)
                
                # Simple confidence intervals (fast)
                result_with_ci = compute_ci(result, 0.683, method="simple")
                elapsed = time() - start_time
                
                push!(times, elapsed)
                push!(first_values, result.deviation[1])
                push!(ci_widths, result_with_ci.ci[1,2] - result_with_ci.ci[1,1])
                
                dev_val = result.deviation[1]
                ci_width = result_with_ci.ci[1,2] - result_with_ci.ci[1,1]
                println("$(round(elapsed, digits=2))s (dev=$dev_val, ci_width=$(round(ci_width*1e9, digits=1))ns)")
                
            catch e
                println("FAILED: $e")
                return nothing
            end
        end
        
        # Statistics
        mean_time = mean(times)
        std_time = std(times)
        mean_first_val = mean(first_values)
        std_first_val = std(first_values)
        mean_ci_width = mean(ci_widths)
        total_time = sum(times)
        throughput = (N * num_datasets) / total_time / 1e6
        
        # Get tau points from last result
        last_result = func(datasets[1], tau0)  # Quick calc for tau count
        tau_points = length(last_result.tau)
        
        println("  Results:")
        println("    Mean time: $(round(mean_time, digits=3)) ± $(round(std_time, digits=3))s")
        println("    Total time: $(round(total_time, digits=2))s")
        println("    First value: $mean_first_val ± $std_first_val")
        println("    Mean CI width: $(round(mean_ci_width*1e9, digits=2))ns")
        println("    Tau points: $tau_points")
        println("    Throughput: $(round(throughput, digits=2)) Msamples/sec")
        println()
        
        results[func_key] = Dict(
            "times" => times,
            "mean_time" => mean_time,
            "std_time" => std_time,
            "total_time" => total_time,
            "first_values" => first_values,
            "mean_first_val" => mean_first_val,
            "std_first_val" => std_first_val,
            "ci_widths" => ci_widths,
            "mean_ci_width" => mean_ci_width,
            "tau_points" => tau_points,
            "throughput" => throughput
        )
    end
    
    # Overall summary
    grand_total_time = sum([results[func_key]["total_time"] for func_key in ["oadev", "mdev", "ohdev"]])
    overall_throughput = (N * num_datasets * 3) / grand_total_time / 1e6
    
    println("🏁 FAIR JULIA BENCHMARK SUMMARY")
    println("=" ^ 60)
    println("Total execution time: $(round(grand_total_time, digits=1))s ($(round(grand_total_time/60, digits=1)) min)")
    println()
    println("Function | Mean Time | Total Time | Tau Points | CI Width | Throughput")
    println("---------|-----------|------------|------------|----------|------------")
    
    for func_key in ["oadev", "mdev", "ohdev"]
        result = results[func_key]
        ci_width_ns = round(result["mean_ci_width"] * 1e9, digits=1)
        println("$(rpad(uppercase(func_key), 8)) | $(lpad(string(round(result["mean_time"], digits=3)), 9)) | $(lpad(string(round(result["total_time"], digits=1)), 10)) | $(lpad(string(result["tau_points"]), 10)) | $(lpad(string(ci_width_ns) * "ns", 8)) | $(lpad(string(round(result["throughput"], digits=1)) * " Msmp/s", 11))")
    end
    
    println("---------|-----------|------------|------------|----------|------------")
    println("$(rpad("OVERALL", 8)) | $(lpad("-", 9)) | $(lpad(string(round(grand_total_time, digits=1)), 10)) | $(lpad("-", 10)) | $(lpad("-", 8)) | $(lpad(string(round(overall_throughput, digits=1)) * " Msmp/s", 11))")
    
    # Save results
    open("/tmp/julia_fair_benchmark_results.txt", "w") do io
        for (key, value) in results
            println(io, "$key:")
            for (subkey, subvalue) in value
                println(io, "  $subkey: $subvalue")
            end
            println(io)
        end
    end
    
    println()
    println("💾 Results saved to /tmp/julia_fair_benchmark_results.txt")
    println()
    println("✅ Fair benchmark completed!")
    println("   This uses simple σ/√n confidence intervals like AllanTools")
    println("   Ready for direct performance comparison! 🚀")
    
    return results
end

if abspath(PROGRAM_FILE) == @__FILE__
    fair_benchmark_julia()
end