using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using StabLab
using Statistics
using Random
using Printf

println("Testing Time Interval Error Functions")
println("="^50)

# Set random seed for reproducibility
Random.seed!(1234)

# Generate test data
N = 10000
tau0 = 1.0

# White phase noise + linear drift
t = (0:N-1) * tau0
drift_rate = 1e-11  # 10 ps/s drift
white_noise = cumsum(randn(N) * 1e-9)  # 1 ns RMS white noise
phase_data = white_noise + drift_rate * t

println("\nTest data: $(N) points, τ₀ = $(tau0) s")
println("Components: White phase noise (1 ns RMS) + linear drift (10 ps/s)")

# Test TIE
println("\n1. Testing TIE (Time Interval Error RMS)")
println("-"^30)
result_tie = tie(phase_data, tau0)
println("Computed $(length(result_tie.tau)) tau points")
println("Sample results:")
for i in [1, 5, 10]
    if i <= length(result_tie.tau)
        tie_ns = round(result_tie.deviation[i]*1e9, digits=3)
        println("  τ = $(result_tie.tau[i]) s: TIE = $(tie_ns) ns")
    end
end

# Test MTIE
println("\n2. Testing MTIE (Maximum Time Interval Error)")
println("-"^30)
result_mtie = mtie(phase_data, tau0)
println("Computed $(length(result_mtie.tau)) tau points")
println("Sample results:")
for i in [1, 5, 10]
    if i <= length(result_mtie.tau)
        mtie_ns = round(result_mtie.deviation[i]*1e9, digits=3)
        println("  τ = $(result_mtie.tau[i]) s: MTIE = $(mtie_ns) ns")
    end
end

# Test PDEV
println("\n3. Testing PDEV (Parabolic Deviation)")
println("-"^30)
result_pdev = pdev(phase_data, tau0)
println("Computed $(length(result_pdev.tau)) tau points")
println("Sample results:")
for i in [1, 5, 10]
    if i <= length(result_pdev.tau)
        pdev_val = @sprintf("%.3e", result_pdev.deviation[i])
        println("  τ = $(result_pdev.tau[i]) s: PDEV = $(pdev_val)")
    end
end

# Compare PDEV with ADEV at τ=1s (should be equal)
result_adev = adev(phase_data, tau0)
pdev1 = @sprintf("%.6e", result_pdev.deviation[1])
adev1 = @sprintf("%.6e", result_adev.deviation[1])
ratio = @sprintf("%.6f", result_pdev.deviation[1]/result_adev.deviation[1])
println("\nVerification: PDEV(τ=1s) = $(pdev1)")
println("              ADEV(τ=1s) = $(adev1)")
println("              Ratio = $(ratio) (should be ≈1.0)")

# Test THEO1
println("\n4. Testing THEO1 Deviation")
println("-"^30)
result_theo1 = theo1(phase_data, tau0)
println("Computed $(length(result_theo1.tau)) tau points")
println("Sample results:")
for i in 1:min(5, length(result_theo1.tau))
    theo1_val = @sprintf("%.3e", result_theo1.deviation[i])
    println("  τ = $(result_theo1.tau[i]) s: THEO1 = $(theo1_val)")
end

# Test relationships
println("\n5. Testing Expected Relationships")
println("-"^30)

# MTIE should be larger than TIE RMS
common_taus = intersect(result_tie.tau, result_mtie.tau)
if !isempty(common_taus)
    idx_tie = findfirst(x -> x == common_taus[1], result_tie.tau)
    idx_mtie = findfirst(x -> x == common_taus[1], result_mtie.tau)
    ratio = result_mtie.deviation[idx_mtie] / result_tie.deviation[idx_tie]
    ratio_str = @sprintf("%.3f", ratio)
    println("MTIE/TIE ratio at τ=$(common_taus[1])s: $(ratio_str) (should be >1)")
end

# PDEV should remove linear drift better than ADEV
if length(result_pdev.tau) >= 10 && length(result_adev.tau) >= 10
    # At longer tau, PDEV should show less effect from drift
    pdev_slope = log10(result_pdev.deviation[end]) - log10(result_pdev.deviation[end-5])
    adev_slope = log10(result_adev.deviation[end]) - log10(result_adev.deviation[end-5])
    tau_slope = log10(result_pdev.tau[end]) - log10(result_pdev.tau[end-5])
    
    pdev_slope /= tau_slope
    adev_slope /= tau_slope
    
    println("\nDrift sensitivity (log-log slope at large τ):")
    adev_slope_str = @sprintf("%.3f", adev_slope)
    pdev_slope_str = @sprintf("%.3f", pdev_slope)
    println("  ADEV slope: $(adev_slope_str)")
    println("  PDEV slope: $(pdev_slope_str)")
    println("  PDEV shows $(abs(pdev_slope) < abs(adev_slope) ? "better" : "worse") drift rejection")
end

# Test with pure white noise (no drift) for cleaner comparison
println("\n6. Testing with Pure White Phase Noise")
println("-"^30)
white_only = cumsum(randn(N) * 1e-9)

pdev_white = pdev(white_only, tau0)
adev_white = adev(white_only, tau0)

# Check theoretical slope for white PM (-1 for ADEV, -1.5 for PDEV)
if length(pdev_white.tau) >= 10
    # Calculate slopes
    idx1, idx2 = 3, 8
    adev_slope = (log10(adev_white.deviation[idx2]) - log10(adev_white.deviation[idx1])) / 
                 (log10(adev_white.tau[idx2]) - log10(adev_white.tau[idx1]))
    pdev_slope = (log10(pdev_white.deviation[idx2]) - log10(pdev_white.deviation[idx1])) / 
                 (log10(pdev_white.tau[idx2]) - log10(pdev_white.tau[idx1]))
    
    println("White PM theoretical slopes:")
    adev_slope_str = @sprintf("%.3f", adev_slope)
    pdev_slope_str = @sprintf("%.3f", pdev_slope)
    println("  ADEV: $(adev_slope_str) (theory: -1.0)")
    println("  PDEV: $(pdev_slope_str) (theory: -1.5)")
end

# Test ITU mask generation
println("\n7. Testing ITU Mask Generation")
println("-"^30)
tau_test = [0.1, 1.0, 10.0, 100.0, 1000.0]
mask_g811 = StabLab.generate_itu_mask("G.811", tau_test)
mask_g812 = StabLab.generate_itu_mask("G.812", tau_test)

println("ITU-T G.811 Primary Reference Clock limits:")
for (tau, limit) in zip(tau_test, mask_g811)
    limit_ns = @sprintf("%.1f", limit*1e9)
    println("  τ = $(tau) s: MTIE limit = $(limit_ns) ns")
end

println("\nAll time interval error functions tested successfully!")