# Professional plotting example for StabLab.jl
# Demonstrates ADEV analysis with confidence intervals and professional output

using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using StabLab

function main()
    println("StabLab.jl Professional Plotting Example")
    println("="^50)
    
    # Load the rubidium clock data
    data_file = "6krb25apr.txt"
    println("Loading phase data from $data_file...")
    
    try
        # Load phase data (scale from ns to s)
        phase_data = load_phase_data(data_file, tau0=1.0, scale=1e-9)
        
        println("\nPerforming Allan deviation analysis...")
        
        # Compute Allan deviation
        result = adev(phase_data, 1.0)
        println("Basic ADEV computed with $(length(result.tau)) tau points")
        
        # Add confidence intervals using full EDF method
        println("Computing confidence intervals with EDF analysis...")
        result_with_ci = compute_ci(result, 0.683, method="full")
        
        # Create professional plot
        println("\nGenerating professional stability plot...")
        p = stabplot(result_with_ci, 
                    title="Rubidium Clock Stability Analysis (6krb25apr)",
                    show_ci=true,
                    logscale=true,
                    save_path="rubidium_adev_analysis.png",
                    show_table=true)
        
        println("\nPlot saved as 'rubidium_adev_analysis.png'")
        
        # Also create a comprehensive report with multiple methods
        println("\nGenerating comprehensive stability report...")
        methods = ["adev", "mdev", "hdev"]
        results, plots = stability_report(phase_data, 1.0, 
                                         methods=methods,
                                         save_path="rubidium_report")
        
        println("\nAnalysis complete!")
        println("Files generated:")
        println("  - rubidium_adev_analysis.png (main ADEV plot)")
        for method in methods
            println("  - rubidium_report_$(method).png")
        end
        
        return results
        
    catch e
        println("Error: $e")
        println("\nMake sure the data file '$data_file' exists in the examples/ directory")
        return nothing
    end
end

# Run the example
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end