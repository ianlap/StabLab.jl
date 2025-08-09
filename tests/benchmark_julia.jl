# Benchmark StabLab.jl functions against allantools results
# Tests: hdev, mdev, adev with large datasets (5e6 samples)

using Pkg
Pkg.activate(".")

using StabLab
using NPZ
using Random

function load_benchmark_data()
    # Load phase data
    phase_data = npzread("/tmp/benchmark_phase_data.npy")
    println("Loaded phase data: $(length(phase_data)) samples")
    
    # Load allantools results
    allantools_results = npzread("/tmp/allantools_results.npz")
    println("Loaded allantools reference results")
    
    return phase_data, allantools_results
end

function benchmark_stablab(phase_data, tau0=1.0, max_tau_points=20)
    # Benchmark StabLab.jl functions
    println("\n=== StabLab.jl (Julia) Benchmark ===")
    
    N = length(phase_data)
    
    # Generate m_list (octave-spaced) - matching Python
    max_m = N ÷ 4
    m_list = Int[]
    m = 1
    while m <= max_m && length(m_list) < max_tau_points
        push!(m_list, m)
        m *= 2
    end
    
    results = Dict{String, Any}()
    
    # Test ADEV
    println("Testing ADEV with $N samples...")
    adev_time = @elapsed begin
        try
            result_adev = adev(phase_data, tau0, mlist=m_list)
            results["adev"] = result_adev
            println("  ✓ ADEV: $(length(result_adev.tau)) points")
        catch e
            println("  ❌ ADEV failed: $e")
        end
    end
    if haskey(results, "adev")
        results["adev_time"] = adev_time
        println("  Time: $(adev_time:.3f)s")
    end
    
    # Test MDEV  
    println("Testing MDEV with $N samples...")
    mdev_time = @elapsed begin
        try
            result_mdev = mdev(phase_data, tau0, mlist=m_list)
            results["mdev"] = result_mdev
            println("  ✓ MDEV: $(length(result_mdev.tau)) points")
        catch e
            println("  ❌ MDEV failed: $e")
        end
    end
    if haskey(results, "mdev")
        results["mdev_time"] = mdev_time
        println("  Time: $(mdev_time:.3f)s")
    end
    
    # Test HDEV
    println("Testing HDEV with $N samples...")
    hdev_time = @elapsed begin
        try
            result_hdev = hdev(phase_data, tau0, mlist=m_list)
            results["hdev"] = result_hdev
            println("  ✓ HDEV: $(length(result_hdev.tau)) points")
        catch e
            println("  ❌ HDEV failed: $e")
        end
    end
    if haskey(results, "hdev")
        results["hdev_time"] = hdev_time
        println("  Time: $(hdev_time:.3f)s")
    end
    
    return results
end

function compare_results(julia_results, allantools_results)
    # Compare Julia results with allantools
    println("\n=== Accuracy Comparison: StabLab.jl vs AllanTools ===")
    
    functions = ["adev", "mdev", "hdev"]
    
    for func_name in functions
        if haskey(julia_results, func_name)
            julia_result = julia_results[func_name]
            
            # Get allantools reference
            at_tau_key = "$(func_name)_tau"
            at_dev_key = "$(func_name)_dev"
            
            if haskey(allantools_results, at_tau_key) && haskey(allantools_results, at_dev_key)
                at_tau = allantools_results[at_tau_key]
                at_dev = allantools_results[at_dev_key]
                
                println("\n$(uppercase(func_name)) Comparison:")
                println("Tau (s)     | Julia        | AllanTools   | Rel. Error")
                println("------------|--------------|--------------|------------")
                
                # Compare first few points
                n_compare = min(5, length(julia_result.tau), length(at_tau))
                max_rel_error = 0.0
                
                for i in 1:n_compare
                    j_tau = julia_result.tau[i]
                    j_dev = julia_result.deviation[i]
                    
                    # Find closest tau in allantools results
                    at_idx = argmin(abs.(at_tau .- j_tau))
                    at_tau_val = at_tau[at_idx]
                    at_dev_val = at_dev[at_idx]
                    
                    rel_error = abs(j_dev - at_dev_val) / at_dev_val * 100
                    max_rel_error = max(max_rel_error, rel_error)
                    
                    println("$(rpad(round(j_tau, digits=1), 11)) | $(rpad(round(j_dev, sigdigits=6), 12)) | $(rpad(round(at_dev_val, sigdigits=6), 12)) | $(round(rel_error, digits=2))%")
                end
                
                println("Max relative error: $(round(max_rel_error, digits=3))%")
                
                if max_rel_error < 1.0
                    println("✓ Excellent agreement (< 1% error)")
                elseif max_rel_error < 5.0
                    println("✓ Good agreement (< 5% error)")
                else
                    println("⚠️  Significant differences (> 5% error)")
                end
            else
                println("No allantools reference for $func_name")
            end
        end
    end
end

function performance_summary(julia_results, allantools_results)
    # Performance summary
    println("\n=== Performance Summary ===")
    
    functions = ["adev", "mdev", "hdev"]
    julia_total = 0.0
    python_total = 0.0
    
    println("Function | Julia (s) | Python (s) | Speedup")
    println("---------|-----------|------------|--------")
    
    for func_name in functions
        if haskey(julia_results, "$(func_name)_time")
            julia_time = julia_results["$(func_name)_time"]
            julia_total += julia_time
            
            python_time_key = "$(func_name)_time"
            if haskey(allantools_results, python_time_key)
                python_time = allantools_results[python_time_key]
                python_total += python_time
                speedup = python_time / julia_time
                
                println("$(rpad(uppercase(func_name), 8)) | $(rpad(round(julia_time, digits=3), 9)) | $(rpad(round(python_time, digits=3), 10)) | $(round(speedup, digits=2))x")
            else
                println("$(rpad(uppercase(func_name), 8)) | $(rpad(round(julia_time, digits=3), 9)) | N/A        | N/A")
            end
        end
    end
    
    if python_total > 0
        overall_speedup = python_total / julia_total
        println("---------|-----------|------------|--------")
        println("$(rpad("TOTAL", 8)) | $(rpad(round(julia_total, digits=3), 9)) | $(rpad(round(python_total, digits=3), 10)) | $(round(overall_speedup, digits=2))x")
        
        if overall_speedup > 1.0
            println("\n🚀 Julia is $(round(overall_speedup, digits=2))x faster than Python!")
        else
            println("\n⚠️  Python is $(round(1/overall_speedup, digits=2))x faster than Julia")
        end
    end
end

function main()
    println("StabLab.jl Performance Benchmark")
    println("=" ^ 50)
    
    try
        # Load benchmark data
        phase_data, allantools_results = load_benchmark_data()
        
        # Run Julia benchmark
        julia_results = benchmark_stablab(phase_data)
        
        # Compare accuracy
        compare_results(julia_results, allantools_results)
        
        # Performance summary
        performance_summary(julia_results, allantools_results)
        
        println("\n🎉 Benchmark completed successfully!")
        
    catch e
        println("❌ Benchmark failed: $e")
        println("Make sure to run the Python script first to generate reference data.")
    end
end

# Run benchmark
main()