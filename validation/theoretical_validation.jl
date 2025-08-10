using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using StabLab
using Plots
using Random
using Printf
using Statistics

println("StabLab.jl Theoretical Validation")
println("="^40)

# Test theoretical relationships and noise slopes
Random.seed!(123)  # Different seed for variety

# Generate different noise types with known theoretical slopes
N = 8000
tau0 = 1.0

noise_types = []

# 1. White Phase Noise (τ^-1/2 slope)
println("Generating White Phase Noise...")
wpm_phase = cumsum(randn(N)) * 1e-9
push!(noise_types, (wpm_phase, "White Phase Noise", "τ^(-1/2)", -0.5))

# 2. Flicker Phase Noise (τ^-1 slope) - approximate
println("Generating Flicker Phase Noise...")
# Generate flicker phase by filtering white noise
fpm_phase = zeros(N)
for i in 2:N
    fpm_phase[i] = fpm_phase[i-1] + randn() / sqrt(i) * 1e-9
end
push!(noise_types, (fpm_phase, "Flicker Phase Noise", "τ^(-1)", -1.0))

# 3. White Frequency Noise (flat slope)
println("Generating White Frequency Noise...")
wfm_freq = randn(N) * 1e-11
wfm_phase = cumsum(cumsum(wfm_freq)) * tau0^2
push!(noise_types, (wfm_phase, "White Frequency Noise", "τ^0", 0.0))

# 4. Flicker Frequency Noise (τ^1/2 slope) - approximate
println("Generating Flicker Frequency Noise...")
ffm_freq = zeros(N)
for i in 1:N
    ffm_freq[i] = randn() / sqrt(max(1,i)) * 1e-12
end
ffm_phase = cumsum(cumsum(ffm_freq)) * tau0^2
push!(noise_types, (ffm_phase, "Flicker Frequency Noise", "τ^(1/2)", 0.5))

# 5. Random Walk Frequency (τ^1/2 slope)
println("Generating Random Walk Frequency...")
rwfm_freq = cumsum(randn(N)) * 1e-12
rwfm_phase = cumsum(cumsum(rwfm_freq)) * tau0^2
push!(noise_types, (rwfm_phase, "Random Walk Frequency", "τ^(1/2)", 0.5))

# Test all deviation types on each noise
deviation_functions = [
    ("adev", adev, "Allan Deviation"),
    ("mdev", mdev, "Modified Allan Deviation"),
    ("hdev", hdev, "Hadamard Deviation"),
    ("mhdev", mhdev, "Modified Hadamard Deviation"),
    ("pdev", pdev, "Parabolic Deviation")
]

# Create slope analysis plots
all_plots = []

for (noise_data, noise_name, expected_slope_str, expected_slope) in noise_types
    println("\nAnalyzing $noise_name...")
    
    subplot_array = []
    
    for (func_name, func, func_title) in deviation_functions
        try
            result = func(noise_data, tau0)
            
            # Compute actual slope using linear regression on log-log data
            log_tau = log10.(result.tau)
            log_dev = log10.(result.deviation)
            
            # Remove any infinite or NaN values
            valid_idx = isfinite.(log_tau) .&& isfinite.(log_dev)
            if sum(valid_idx) > 2
                log_tau_clean = log_tau[valid_idx]
                log_dev_clean = log_dev[valid_idx]
                
                # Linear fit: log(dev) = slope * log(tau) + intercept
                n_points = length(log_tau_clean)
                slope = (n_points * sum(log_tau_clean .* log_dev_clean) - sum(log_tau_clean) * sum(log_dev_clean)) / 
                       (n_points * sum(log_tau_clean.^2) - sum(log_tau_clean)^2)
                intercept = (sum(log_dev_clean) - slope * sum(log_tau_clean)) / n_points
                
                # Create theoretical line
                tau_theory = [minimum(result.tau), maximum(result.tau)]
                dev_theory = 10.0.^(slope .* log10.(tau_theory) .+ intercept)
                
                p = plot(result.tau, result.deviation,
                        marker=:circle, linewidth=2, markersize=3,
                        xscale=:log10, yscale=:log10,
                        xlabel="τ (s)", ylabel="Deviation",
                        title="$func_title\\nSlope: $(round(slope, digits=3)) (exp: $expected_slope)",
                        label="$func_name data",
                        grid=true, minorgrid=true)
                
                plot!(p, tau_theory, dev_theory,
                      line=(:dash, 2), color=:red,
                      label="Fitted: τ^$(round(slope, digits=2))")
                
                # Color code based on accuracy
                slope_error = abs(slope - expected_slope)
                title_color = slope_error < 0.1 ? :green : (slope_error < 0.3 ? :orange : :red)
                plot!(p, title=p.attr[:title], titlefontcolor=title_color)
                
            else
                p = plot(title="$func_title (INSUFFICIENT DATA)",
                        xlabel="τ (s)", ylabel="Deviation")
            end
            
            push!(subplot_array, p)
            
        catch e
            println("  Warning: $func_name failed: $e")
            p = plot(title="$func_title (FAILED)", 
                    xlabel="τ (s)", ylabel="Deviation")
            push!(subplot_array, p)
        end
    end
    
    # Create combined plot for this noise type
    noise_plot = plot(subplot_array...,
                     layout=(2,3), size=(1500,1000),
                     plot_title="Theoretical Validation: $noise_name (Expected: $expected_slope_str)",
                     titlefontsize=16)
    
    push!(all_plots, noise_plot)
    
    # Save individual noise type plot
    filename = "validation/theoretical_$(replace(lowercase(noise_name), " " => "_")).png"
    savefig(noise_plot, filename)
    println("  Saved: $filename")
end

# Test mathematical relationships
println("\n" * "="^60)
println("MATHEMATICAL RELATIONSHIP VALIDATION")
println("="^60)

# Test TDEV = τ * MDEV / sqrt(3)
test_data = noise_types[1][1]  # Use white phase noise
mdev_result = mdev(test_data, tau0)
tdev_result = tdev(test_data, tau0)

println("\nTDEV vs MDEV Relationship Test:")
println("Expected: TDEV = τ × MDEV / √3")
println("τ (s)    | TDEV      | τ×MDEV/√3 | Ratio   | Diff (%)")
println("-"^55)

tdev_theory_errors = []
for i in 1:min(5, length(mdev_result.tau))
    tau_val = mdev_result.tau[i]
    mdev_val = mdev_result.deviation[i]
    
    # Find corresponding TDEV point
    tdev_idx = argmin(abs.(tdev_result.tau .- tau_val))
    if abs(tdev_result.tau[tdev_idx] - tau_val) < 0.1
        tdev_val = tdev_result.deviation[tdev_idx]
        tdev_theory = tau_val * mdev_val / sqrt(3)
        ratio = tdev_val / tdev_theory
        diff_pct = abs(tdev_val - tdev_theory) / tdev_theory * 100
        
        push!(tdev_theory_errors, diff_pct)
        
        println(@sprintf("%-8.1f | %-9.3e | %-9.3e | %-7.4f | %-7.2f%%",
                        tau_val, tdev_val, tdev_theory, ratio, diff_pct))
    end
end

if !isempty(tdev_theory_errors)
    mean_error = mean(tdev_theory_errors)
    println("Mean theoretical error: $(round(mean_error, digits=3))%")
    if mean_error < 1.0
        println("✓ TDEV relationship validated (error < 1%)")
    else
        println("⚠ TDEV relationship needs investigation (error ≥ 1%)")
    end
end

# Test LDEV = τ * MHDEV / sqrt(10/3)
mhdev_result = mhdev(test_data, tau0)
ldev_result = ldev(test_data, tau0)

println("\nLDEV vs MHDEV Relationship Test:")
println("Expected: LDEV = τ × MHDEV / √(10/3)")
println("τ (s)    | LDEV      | τ×MHDEV/√(10/3) | Ratio   | Diff (%)")
println("-"^60)

ldev_theory_errors = []
for i in 1:min(5, length(mhdev_result.tau))
    tau_val = mhdev_result.tau[i]
    mhdev_val = mhdev_result.deviation[i]
    
    # Find corresponding LDEV point
    ldev_idx = argmin(abs.(ldev_result.tau .- tau_val))
    if abs(ldev_result.tau[ldev_idx] - tau_val) < 0.1
        ldev_val = ldev_result.deviation[ldev_idx]
        ldev_theory = tau_val * mhdev_val / sqrt(10/3)
        ratio = ldev_val / ldev_theory
        diff_pct = abs(ldev_val - ldev_theory) / ldev_theory * 100
        
        push!(ldev_theory_errors, diff_pct)
        
        println(@sprintf("%-8.1f | %-9.3e | %-11.3e | %-7.4f | %-7.2f%%",
                        tau_val, ldev_val, ldev_theory, ratio, diff_pct))
    end
end

if !isempty(ldev_theory_errors)
    mean_error = mean(ldev_theory_errors)
    println("Mean theoretical error: $(round(mean_error, digits=3))%")
    if mean_error < 1.0
        println("✓ LDEV relationship validated (error < 1%)")
    else
        println("⚠ LDEV relationship needs investigation (error ≥ 1%)")
    end
end

# Test PDEV = ADEV at m=1
adev_result = adev(test_data, tau0)
pdev_result = pdev(test_data, tau0)

println("\nPDEV vs ADEV at m=1 Test:")
adev_1s = adev_result.deviation[1]
pdev_1s = pdev_result.deviation[1]
ratio = pdev_1s / adev_1s
diff_pct = abs(pdev_1s - adev_1s) / adev_1s * 100

println(@sprintf("ADEV(1s) = %.6e", adev_1s))
println(@sprintf("PDEV(1s) = %.6e", pdev_1s))
println(@sprintf("Ratio = %.6f, Diff = %.3f%%", ratio, diff_pct))

if diff_pct < 0.1
    println("✓ PDEV = ADEV at m=1 validated")
else
    println("⚠ PDEV ≠ ADEV at m=1 (investigate)")
end

# Create summary theoretical validation plot
summary_plot = plot(size=(1200,800))

# Plot all functions on white phase noise for comparison
test_functions_summary = [
    ("adev", adev, "ADEV", :blue),
    ("mdev", mdev, "MDEV", :red),
    ("hdev", hdev, "HDEV", :green),
    ("mhdev", mhdev, "MHDEV", :orange),
    ("pdev", pdev, "PDEV", :purple)
]

for (func_name, func, func_label, color) in test_functions_summary
    result = func(test_data, tau0)
    plot!(summary_plot, result.tau, result.deviation,
          marker=:circle, linewidth=2, markersize=3,
          xscale=:log10, yscale=:log10,
          label=func_label, color=color)
end

# Add theoretical τ^(-1/2) slope line
tau_ref = test_data |> adev |> r -> r.tau
dev_ref = test_data |> adev |> r -> r.deviation
theory_line = dev_ref[3] .* (tau_ref ./ tau_ref[3]).^(-0.5)
plot!(summary_plot, tau_ref, theory_line,
      line=(:dash, 3), color=:black, alpha=0.7,
      label="τ^(-1/2) theory")

xlabel!(summary_plot, "τ (s)")
ylabel!(summary_plot, "Deviation")
title!(summary_plot, "StabLab.jl Functions on White Phase Noise")
savefig(summary_plot, "validation/theoretical_summary_comparison.png")
println("\nSaved: validation/theoretical_summary_comparison.png")

println("\nTheoretical validation complete!")
println("Generated $(length(noise_types)) noise-specific validation plots plus summary.")