using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using StabLab
using Statistics
using Random
using Printf
using Plots

# Python comparison setup
using PyCall
pushfirst!(PyVector(pyimport("sys")."path"), "/Users/ianlapinski/Desktop/masterclock-kflab/allantools/allantools")
at = pyimport("allantools")

println("StabLab.jl vs AllanTools Comparison: Time Interval Error Functions")
println("="^80)

# Set random seed for reproducibility
Random.seed!(12345)

# Generate test data
N = 10000
tau0 = 1.0

# Test 1: White phase noise
println("\nGenerating test data: $(N) points, white phase noise")
phase_data = cumsum(randn(N) * 1e-9)  # 1 ns RMS white noise

# Test TIE comparison
println("\n1. TIE (Time Interval Error) Comparison")
println("-"^50)

# Julia StabLab
julia_tie = tie(phase_data, tau0)
julia_tau = julia_tie.tau
julia_tie_dev = julia_tie.deviation

# Python AllanTools - tierms function
py_tau_tie, py_tie_dev, py_tie_err, py_tie_n = at.tierms(phase_data, rate=1/tau0, data_type="phase", taus="octave")
py_tau_tie = py_tau_tie[py_tau_tie .<= maximum(julia_tau)]  # Match range
py_tie_dev = py_tie_dev[1:length(py_tau_tie)]

println("Julia TIE points: $(length(julia_tau))")
println("Python TIE points: $(length(py_tau_tie))")

# Create comparison plot for TIE
p1 = plot(julia_tau, julia_tie_dev * 1e9, 
          xscale=:log10, yscale=:log10,
          marker=:circle, linewidth=2,
          label="Julia StabLab", 
          xlabel="τ (s)", ylabel="TIE (ns)",
          title="Time Interval Error Comparison")

plot!(py_tau_tie, py_tie_dev * 1e9,
      marker=:square, linewidth=2,
      label="Python AllanTools")

savefig(p1, "tie_comparison.png")
println("TIE comparison plot saved as 'tie_comparison.png'")

# Test MTIE comparison
println("\n2. MTIE (Maximum Time Interval Error) Comparison")
println("-"^50)

# Julia StabLab
julia_mtie = mtie(phase_data, tau0)
julia_mtie_tau = julia_mtie.tau
julia_mtie_dev = julia_mtie.deviation

# Python AllanTools
py_tau_mtie, py_mtie_dev, py_mtie_err, py_mtie_n = at.mtie(phase_data, rate=1/tau0, data_type="phase", taus="octave")
py_tau_mtie = py_tau_mtie[py_tau_mtie .<= maximum(julia_mtie_tau)]
py_mtie_dev = py_mtie_dev[1:length(py_tau_mtie)]

println("Julia MTIE points: $(length(julia_mtie_tau))")
println("Python MTIE points: $(length(py_tau_mtie))")

# Create comparison plot for MTIE
p2 = plot(julia_mtie_tau, julia_mtie_dev * 1e9,
          xscale=:log10, yscale=:log10,
          marker=:circle, linewidth=2,
          label="Julia StabLab",
          xlabel="τ (s)", ylabel="MTIE (ns)",
          title="Maximum Time Interval Error Comparison")

plot!(py_tau_mtie, py_mtie_dev * 1e9,
      marker=:square, linewidth=2,
      label="Python AllanTools")

savefig(p2, "mtie_comparison.png")
println("MTIE comparison plot saved as 'mtie_comparison.png'")

# Test PDEV comparison
println("\n3. PDEV (Parabolic Deviation) Comparison")
println("-"^50)

# Julia StabLab
julia_pdev = pdev(phase_data, tau0)
julia_pdev_tau = julia_pdev.tau
julia_pdev_dev = julia_pdev.deviation

# Python AllanTools
py_tau_pdev, py_pdev_dev, py_pdev_err, py_pdev_n = at.pdev(phase_data, rate=1/tau0, data_type="phase", taus="octave")
py_tau_pdev = py_tau_pdev[py_tau_pdev .<= maximum(julia_pdev_tau)]
py_pdev_dev = py_pdev_dev[1:length(py_tau_pdev)]

println("Julia PDEV points: $(length(julia_pdev_tau))")
println("Python PDEV points: $(length(py_tau_pdev))")

# Create comparison plot for PDEV
p3 = plot(julia_pdev_tau, julia_pdev_dev,
          xscale=:log10, yscale=:log10,
          marker=:circle, linewidth=2,
          label="Julia StabLab",
          xlabel="τ (s)", ylabel="PDEV",
          title="Parabolic Deviation Comparison")

plot!(py_tau_pdev, py_pdev_dev,
      marker=:square, linewidth=2,
      label="Python AllanTools")

savefig(p3, "pdev_comparison.png")
println("PDEV comparison plot saved as 'pdev_comparison.png'")

# Test THEO1 comparison
println("\n4. THEO1 Deviation Comparison")
println("-"^50)

# Julia StabLab
julia_theo1 = theo1(phase_data, tau0)
julia_theo1_tau = julia_theo1.tau
julia_theo1_dev = julia_theo1.deviation

# Python AllanTools
py_tau_theo1, py_theo1_dev, py_theo1_err, py_theo1_n = at.theo1(phase_data, rate=1/tau0, data_type="phase", taus="octave")
# Filter for even taus only (THEO1 requirement)
even_mask = [t % (2*tau0) == 0 for t in py_tau_theo1]
py_tau_theo1 = py_tau_theo1[even_mask]
py_theo1_dev = py_theo1_dev[even_mask]
py_tau_theo1 = py_tau_theo1[py_tau_theo1 .<= maximum(julia_theo1_tau)]
py_theo1_dev = py_theo1_dev[1:length(py_tau_theo1)]

println("Julia THEO1 points: $(length(julia_theo1_tau))")
println("Python THEO1 points: $(length(py_tau_theo1))")

# Create comparison plot for THEO1
p4 = plot(julia_theo1_tau, julia_theo1_dev,
          xscale=:log10, yscale=:log10,
          marker=:circle, linewidth=2,
          label="Julia StabLab",
          xlabel="τ (s)", ylabel="THEO1 Deviation",
          title="THEO1 Deviation Comparison")

plot!(py_tau_theo1, py_theo1_dev,
      marker=:square, linewidth=2,
      label="Python AllanTools")

savefig(p4, "theo1_comparison.png")
println("THEO1 comparison plot saved as 'theo1_comparison.png'")

# Create combined comparison plot
println("\n5. Creating Combined Comparison Plot")
println("-"^50)

p_combined = plot(layout=(2,2), size=(1200, 800))

# TIE subplot
plot!(p_combined[1], julia_tau, julia_tie_dev * 1e9,
      xscale=:log10, yscale=:log10,
      marker=:circle, linewidth=2, label="Julia",
      xlabel="τ (s)", ylabel="TIE (ns)", title="TIE Comparison")
plot!(p_combined[1], py_tau_tie, py_tie_dev * 1e9,
      marker=:square, linewidth=2, label="Python")

# MTIE subplot  
plot!(p_combined[2], julia_mtie_tau, julia_mtie_dev * 1e9,
      xscale=:log10, yscale=:log10,
      marker=:circle, linewidth=2, label="Julia",
      xlabel="τ (s)", ylabel="MTIE (ns)", title="MTIE Comparison")
plot!(p_combined[2], py_tau_mtie, py_mtie_dev * 1e9,
      marker=:square, linewidth=2, label="Python")

# PDEV subplot
plot!(p_combined[3], julia_pdev_tau, julia_pdev_dev,
      xscale=:log10, yscale=:log10,
      marker=:circle, linewidth=2, label="Julia",
      xlabel="τ (s)", ylabel="PDEV", title="PDEV Comparison")
plot!(p_combined[3], py_tau_pdev, py_pdev_dev,
      marker=:square, linewidth=2, label="Python")

# THEO1 subplot
plot!(p_combined[4], julia_theo1_tau, julia_theo1_dev,
      xscale=:log10, yscale=:log10,
      marker=:circle, linewidth=2, label="Julia",
      xlabel="τ (s)", ylabel="THEO1", title="THEO1 Comparison")
plot!(p_combined[4], py_tau_theo1, py_theo1_dev,
      marker=:square, linewidth=2, label="Python")

savefig(p_combined, "all_time_errors_comparison.png")
println("Combined comparison plot saved as 'all_time_errors_comparison.png'")

# Numerical comparison at common tau points
println("\n6. Numerical Comparison at Common Tau Values")
println("-"^50)

function find_closest_tau(target_tau, tau_array, dev_array)
    if isempty(tau_array)
        return NaN
    end
    idx = argmin(abs.(tau_array .- target_tau))
    return dev_array[idx]
end

common_taus = [1.0, 2.0, 4.0, 8.0, 16.0, 32.0, 64.0]

println("Tau (s)   | Julia TIE  | Python TIE | Ratio    | Julia MTIE | Python MTIE | Ratio")
println("-"^80)
for tau in common_taus
    j_tie = find_closest_tau(tau, julia_tau, julia_tie_dev)
    p_tie = find_closest_tau(tau, py_tau_tie, py_tie_dev)
    j_mtie = find_closest_tau(tau, julia_mtie_tau, julia_mtie_dev)
    p_mtie = find_closest_tau(tau, py_tau_mtie, py_mtie_dev)
    
    tie_ratio = isnan(j_tie) || isnan(p_tie) ? NaN : j_tie/p_tie
    mtie_ratio = isnan(j_mtie) || isnan(p_mtie) ? NaN : j_mtie/p_mtie
    
    println(@sprintf("%-8.1f  | %-10.3e | %-10.3e | %-8.3f | %-10.3e | %-11.3e | %-8.3f",
                    tau, j_tie, p_tie, tie_ratio, j_mtie, p_mtie, mtie_ratio))
end

println("\nPDEV Comparison at Common Tau Values:")
println("Tau (s)   | Julia PDEV | Python PDEV | Ratio")
println("-"^45)
for tau in common_taus[1:5]  # PDEV may have fewer points due to instability
    j_pdev = find_closest_tau(tau, julia_pdev_tau, julia_pdev_dev)
    p_pdev = find_closest_tau(tau, py_tau_pdev, py_pdev_dev)
    pdev_ratio = isnan(j_pdev) || isnan(p_pdev) ? NaN : j_pdev/p_pdev
    
    println(@sprintf("%-8.1f  | %-10.3e | %-11.3e | %-8.3f",
                    tau, j_pdev, p_pdev, pdev_ratio))
end

# Performance comparison
println("\n7. Performance Comparison")
println("-"^50)

# Time Julia functions
julia_times = Dict()

print("Timing Julia TIE... ")
julia_times["TIE"] = @elapsed tie(phase_data, tau0)
println(@sprintf("%.3f s", julia_times["TIE"]))

print("Timing Julia MTIE... ")
julia_times["MTIE"] = @elapsed mtie(phase_data, tau0)
println(@sprintf("%.3f s", julia_times["MTIE"]))

print("Timing Julia PDEV... ")
julia_times["PDEV"] = @elapsed pdev(phase_data, tau0)
println(@sprintf("%.3f s", julia_times["PDEV"]))

print("Timing Julia THEO1... ")
julia_times["THEO1"] = @elapsed theo1(phase_data, tau0)
println(@sprintf("%.3f s", julia_times["THEO1"]))

# Time Python functions
python_times = Dict()

print("Timing Python TIE... ")
python_times["TIE"] = @elapsed at.tierms(phase_data, rate=1/tau0, data_type="phase", taus="octave")
println(@sprintf("%.3f s", python_times["TIE"]))

print("Timing Python MTIE... ")
python_times["MTIE"] = @elapsed at.mtie(phase_data, rate=1/tau0, data_type="phase", taus="octave")
println(@sprintf("%.3f s", python_times["MTIE"]))

print("Timing Python PDEV... ")
python_times["PDEV"] = @elapsed at.pdev(phase_data, rate=1/tau0, data_type="phase", taus="octave")
println(@sprintf("%.3f s", python_times["PDEV"]))

print("Timing Python THEO1... ")
python_times["THEO1"] = @elapsed at.theo1(phase_data, rate=1/tau0, data_type="phase", taus="octave")
println(@sprintf("%.3f s", python_times["THEO1"]))

println("\nPerformance Summary:")
println("Function | Julia (s) | Python (s) | Speedup")
println("-"^45)
for func in ["TIE", "MTIE", "PDEV", "THEO1"]
    speedup = python_times[func] / julia_times[func]
    println(@sprintf("%-8s | %-9.3f | %-10.3f | %.2fx", 
                    func, julia_times[func], python_times[func], speedup))
end

total_julia = sum(values(julia_times))
total_python = sum(values(python_times))
overall_speedup = total_python / total_julia

println("-"^45)
println(@sprintf("%-8s | %-9.3f | %-10.3f | %.2fx", 
                "TOTAL", total_julia, total_python, overall_speedup))

println("\n" * "="^80)
println("Time Interval Error Functions Comparison Complete!")
println("Files generated:")
println("  - tie_comparison.png")
println("  - mtie_comparison.png") 
println("  - pdev_comparison.png")
println("  - theo1_comparison.png")
println("  - all_time_errors_comparison.png")
println("\nOverall StabLab.jl is $(overall_speedup:.1f)x faster than AllanTools for time interval error functions!")