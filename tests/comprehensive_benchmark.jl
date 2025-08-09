# Comprehensive 3-way benchmark: StabLab.jl (Julia)
# 20 datasets × 1M samples with OADEV, MDEV, OHDEV

using Pkg
Pkg.activate("..")

using StabLab
using Random
using Statistics

function main()
    println("🚀 COMPREHENSIVE BENCHMARK: StabLab.jl (Julia)")
    println("=" ^ 60)
    println("Functions: OADEV, MDEV, OHDEV") 
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
        println("=== Benchmarking $name ===")
        
        times = Float64[]
        first_values = Float64[]
        
        for (i, phase_data) in enumerate(datasets)
            print("  Dataset $i/$num_datasets: ")
            flush(stdout)
            
            start_time = time()
            try
                result = func(phase_data, tau0)
                elapsed = time() - start_time
                
                push!(times, elapsed)
                push!(first_values, result.deviation[1])
                
                dev_val = result.deviation[1]
                println("$(round(elapsed, digits=2))s (dev[0]=$dev_val)")
                
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
        total_time = sum(times)
        throughput = (N * num_datasets) / total_time / 1e6
        
        # Get tau points from last result
        last_result = func(datasets[1], tau0)  # Quick calc for tau count
        tau_points = length(last_result.tau)
        
        println("  Results:")
        println("    Mean time: $(round(mean_time, digits=3)) ± $(round(std_time, digits=3))s")
        println("    Total time: $(round(total_time, digits=2))s")
        println("    First value: $mean_first_val ± $std_first_val")
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
            "tau_points" => tau_points,
            "throughput" => throughput
        )
    end
    
    # Overall summary
    grand_total_time = sum([results[func_key]["total_time"] for func_key in ["oadev", "mdev", "ohdev"]])
    overall_throughput = (N * num_datasets * 3) / grand_total_time / 1e6
    
    println("🏁 JULIA STABLAB SUMMARY")
    println("=" ^ 60)
    println("Total execution time: $(round(grand_total_time, digits=1))s ($(round(grand_total_time/60, digits=1)) min)")
    println()
    println("Function | Mean Time | Total Time | Tau Points | Throughput")
    println("---------|-----------|------------|------------|------------")
    
    for func_key in ["oadev", "mdev", "ohdev"]
        result = results[func_key]
        println("$(rpad(uppercase(func_key), 8)) | $(lpad(string(round(result["mean_time"], digits=3)), 9)) | $(lpad(string(round(result["total_time"], digits=1)), 10)) | $(lpad(string(result["tau_points"]), 10)) | $(lpad(string(round(result["throughput"], digits=1)) * " Msmp/s", 11))")
    end
    
    println("---------|-----------|------------|------------|------------")
    println("$(rpad("OVERALL", 8)) | $(lpad("-", 9)) | $(lpad(string(round(grand_total_time, digits=1)), 10)) | $(lpad("-", 10)) | $(lpad(string(round(overall_throughput, digits=1)) * " Msmp/s", 11))")
    
    # Save results (Julia format)
    # Note: Could use NPZ.jl to match Python format, but native Julia is fine
    open("/tmp/julia_comprehensive_results.txt", "w") do io
        for (key, value) in results
            println(io, "$key:")
            for (subkey, subvalue) in value
                println(io, "  $subkey: $subvalue")
            end
            println(io)
        end
    end
    
    println()
    println("💾 Results saved to /tmp/julia_comprehensive_results.txt")
    
    return results
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end