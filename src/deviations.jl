# Main deviation calculation functions

"""
    adev(phase_data, tau0; mlist=nothing, confidence=0.683)

Compute Allan deviation from phase data.

# Arguments
- `phase_data`: Phase data vector (seconds)
- `tau0`: Sampling interval (seconds)
- `mlist`: Averaging factors (optional, defaults to octave spacing)
- `confidence`: Confidence level for intervals (default: 0.683)

# Returns
- Single output: `DeviationResult` struct
- Multiple outputs: `(tau, adev)`, `(tau, adev, edf)`, etc.

# Example
```julia
# Simple usage
result = adev(phase_data, 1.0)

# Multiple return values
tau, dev = adev(phase_data, 1.0)

# Custom parameters
result = adev(phase_data, 1.0, mlist=[1,2,4,8], confidence=0.95)
```
"""
function adev(phase_data::AbstractVector{T}, tau0::Real; 
              mlist::Union{Nothing,AbstractVector{Int}}=nothing,
              confidence::Real=0.683) where T<:Real
    
    # Validate inputs
    x = validate_phase_data(phase_data)
    tau0 = validate_tau0(tau0)
    N = length(x)
    
    # Default m_list if not provided
    if mlist === nothing
        mlist = default_m_list(N)
    end
    
    # Initialize outputs
    tau = mlist .* tau0
    adev_vals = fill(NaN, length(mlist))
    edf_vals = fill(NaN, length(mlist))
    neff = fill(0, length(mlist))
    
    # Noise identification (placeholder)
    alpha = noise_id(x, mlist, "phase")
    
    # Compute Allan deviation for each m
    for (k, m) in enumerate(mlist)
        L = N - 2*m
        if L <= 0
            break
        end
        neff[k] = L
        
        # Second differences: x(n+2m) - 2x(n+m) + x(n)
        d2 = x[1+2*m:N] - 2*x[1+m:N-m] + x[1:L]
        
        # Allan variance: σ²_y(τ) = ⟨(Δ²x)²⟩ / (2·m²·τ₀²)
        avar = mean(d2.^2) / (2 * m^2 * tau0^2)
        adev_vals[k] = sqrt(avar)
        
        # EDF calculation (placeholder)
        edf_vals[k] = L  # Simple approximation
    end
    
    # Compute confidence intervals
    ci = compute_ci(adev_vals, edf_vals, confidence, alpha, neff)
    
    # Create result structure
    result = DeviationResult(
        tau, adev_vals, edf_vals, ci, alpha, neff,
        tau0, N, "adev", confidence
    )
    
    return result
end

# Multiple dispatch for different return patterns
function adev(phase_data::AbstractVector, tau0::Real, ::Val{2}; kwargs...)
    result = adev(phase_data, tau0; kwargs...)
    return result.tau, result.deviation
end

function adev(phase_data::AbstractVector, tau0::Real, ::Val{3}; kwargs...)
    result = adev(phase_data, tau0; kwargs...)
    return result.tau, result.deviation, result.edf
end

function adev(phase_data::AbstractVector, tau0::Real, ::Val{4}; kwargs...)
    result = adev(phase_data, tau0; kwargs...)
    return result.tau, result.deviation, result.edf, result.ci
end

function adev(phase_data::AbstractVector, tau0::Real, ::Val{5}; kwargs...)
    result = adev(phase_data, tau0; kwargs...)
    return result.tau, result.deviation, result.edf, result.ci, result.alpha
end

"""
    mdev(phase_data, tau0; mlist=nothing, confidence=0.683)

Compute Modified Allan deviation from phase data.
Modified Allan deviation removes dead time effects using triple-difference algorithm.
"""
function mdev(phase_data::AbstractVector{T}, tau0::Real;
              mlist::Union{Nothing,AbstractVector{Int}}=nothing,
              confidence::Real=0.683) where T<:Real
    
    # Validate inputs
    x = validate_phase_data(phase_data)
    tau0 = validate_tau0(tau0)
    N = length(x)
    
    # Default m_list: octave-spaced values with ≥3m points available (exact MATLAB logic)
    if mlist === nothing
        mlist = [2^k for k in 0:floor(Int, log2(N/3))]
    end
    
    # Initialize outputs
    tau = mlist .* tau0
    mdev_vals = fill(NaN, length(mlist))
    edf_vals = fill(NaN, length(mlist))
    neff = fill(0, length(mlist))
    
    # Noise identification (placeholder)
    alpha = noise_id(x, mlist, "phase")
    
    # Precompute cumulative sum (exact MATLAB: x_cumsum = cumsum([0; x]))
    x_cumsum = cumsum([zero(T); x])
    
    # Main loop - exactly matching MATLAB logic
    for k in 1:length(mlist)
        m = mlist[k]
        N_eff_k = N - 3*m + 1
        neff[k] = N_eff_k
        
        if N_eff_k <= 0
            break
        end
        
        # Exact MATLAB indexing translation:
        # s1 = x_cumsum(1+m : N_eff_k+m)     - x_cumsum(1:N_eff_k);
        # s2 = x_cumsum(1+2*m : N_eff_k+2*m) - x_cumsum(1+m : N_eff_k+m);  
        # s3 = x_cumsum(1+3*m : N_eff_k+3*m) - x_cumsum(1+2*m : N_eff_k+2*m);
        s1 = x_cumsum[1+m:N_eff_k+m] - x_cumsum[1:N_eff_k]
        s2 = x_cumsum[1+2*m:N_eff_k+2*m] - x_cumsum[1+m:N_eff_k+m]
        s3 = x_cumsum[1+3*m:N_eff_k+3*m] - x_cumsum[1+2*m:N_eff_k+2*m]
        d = (s3 - 2*s2 + s1) / m
        
        # Exact MATLAB calculation
        mvar = mean(d.^2) / (2 * m^2 * tau0^2)
        mdev_vals[k] = sqrt(mvar)
        
        # EDF calculation (placeholder - would match MATLAB calculate_edf call)
        edf_vals[k] = N_eff_k  # Simple approximation for now
    end
    
    # Compute confidence intervals
    ci = compute_ci(mdev_vals, edf_vals, confidence, alpha, neff)
    
    # Create result structure
    result = DeviationResult(
        tau, mdev_vals, edf_vals, ci, alpha, neff,
        tau0, N, "mdev", confidence
    )
    
    return result
end

"""
    mhdev(phase_data, tau0; mlist=nothing, confidence=0.683)

Compute Modified Hadamard deviation from phase data.
Modified Hadamard deviation combines Hadamard robustness with better convergence.
"""
function mhdev(phase_data::AbstractVector{T}, tau0::Real;
               mlist::Union{Nothing,AbstractVector{Int}}=nothing,
               confidence::Real=0.683) where T<:Real
    
    # Validate inputs
    x = validate_phase_data(phase_data)
    tau0 = validate_tau0(tau0)
    N = length(x)
    
    # Default m_list: octave-spaced values with ≥4m points available (exact MATLAB logic)
    if mlist === nothing
        mlist = [2^k for k in 0:floor(Int, log2(N/4))]
    end
    
    # Initialize outputs
    tau = mlist .* tau0
    mhdev_vals = fill(NaN, length(mlist))
    edf_vals = fill(NaN, length(mlist))
    neff = fill(0, length(mlist))
    
    # Noise identification (placeholder)
    alpha = noise_id(x, mlist, "phase")
    
    # Main loop - exactly matching MATLAB logic
    for k in eachindex(mlist)
        m = mlist[k]
        N_eff = N - 4*m + 1  # from Riley (wriley.com/paper4ht.htm)
        if N_eff <= 0
            break
        end
        
        neff[k] = N_eff
        
        # Third difference: x(n) - 3x(n+m) + 3x(n+2m) - x(n+3m)
        # MATLAB: d4 = x(1:N_eff) - 3*x(1+m:N_eff+m) + 3*x(1+2*m:N_eff+2*m) - x(1+3*m:N_eff+3*m);
        d4 = x[1:N_eff] - 3*x[1+m:N_eff+m] + 3*x[1+2*m:N_eff+2*m] - x[1+3*m:N_eff+3*m]
        
        # Prefix sum for efficient moving average of third differences
        # MATLAB: S = cumsum([0; d4]); avg = S(m+1:end) - S(1:end-m);
        S = cumsum([zero(T); d4])
        avg = S[m+1:end] - S[1:end-m]  # mean over m-point windows
        
        # SP1065 §5.2.10: σ²_H,mod(τ) = ⟨(⟨Δ³x⟩_m)²⟩ / (6·m²)
        # MATLAB: mhvar = mean(avg.^2) / (6 * m^2); mhdev(k) = sqrt(mhvar) / tau(k);
        mhvar = mean(avg.^2) / (6 * m^2)
        mhdev_vals[k] = sqrt(mhvar) / tau[k]
        
        # EDF calculation (placeholder - would match MATLAB calculate_edf call)
        edf_vals[k] = N_eff  # Simple approximation for now
    end
    
    # Compute confidence intervals
    ci = compute_ci(mhdev_vals, edf_vals, confidence, alpha, neff)
    
    # Create result structure
    result = DeviationResult(
        tau, mhdev_vals, edf_vals, ci, alpha, neff,
        tau0, N, "mhdev", confidence
    )
    
    return result
end

"""
    tdev(phase_data, tau0; mlist=nothing, confidence=0.683)

Compute Time deviation from phase data.
Time deviation: TDEV = τ · MDEV / √3

# Arguments
- `phase_data`: Phase data vector (seconds)
- `tau0`: Sampling interval (seconds)
- `mlist`: Averaging factors (optional, defaults to octave spacing)
- `confidence`: Confidence level for intervals (default: 0.683)

# Returns
Time deviation in seconds (note: different units than other deviations)
"""
function tdev(phase_data::AbstractVector{T}, tau0::Real;
              mlist::Union{Nothing,AbstractVector{Int}}=nothing,
              confidence::Real=0.683) where T<:Real
    
    # Compute MDEV first using existing implementation
    mdev_result = mdev(phase_data, tau0, mlist=mlist, confidence=confidence)
    
    # Apply TDEV transformation: TDEV = τ · MDEV / √3
    tdev_vals = mdev_result.tau .* mdev_result.deviation ./ sqrt(3)
    
    # Scale confidence intervals accordingly: TDEV_CI = τ · MDEV_CI / √3
    ci_scaled = mdev_result.ci .* (mdev_result.tau ./ sqrt(3))
    
    # Create result structure
    result = DeviationResult(
        mdev_result.tau, tdev_vals, mdev_result.edf, ci_scaled, mdev_result.alpha, mdev_result.neff,
        mdev_result.tau0, mdev_result.N, "tdev", mdev_result.confidence
    )
    
    return result
end

"""
    ldev(phase_data, tau0; mlist=nothing, confidence=0.683)

Compute Lapinski deviation from phase data.
Lapinski deviation: LDEV = τ · MHDEV / √(10/3)

# Arguments
- `phase_data`: Phase data vector (seconds)
- `tau0`: Sampling interval (seconds)
- `mlist`: Averaging factors (optional, defaults to octave spacing with ≥4m points)
- `confidence`: Confidence level for intervals (default: 0.683)

# Returns
Lapinski deviation in seconds (note: different units than other deviations)
"""
function ldev(phase_data::AbstractVector{T}, tau0::Real;
              mlist::Union{Nothing,AbstractVector{Int}}=nothing,
              confidence::Real=0.683) where T<:Real
    
    # Compute MHDEV first using existing implementation
    mhdev_result = mhdev(phase_data, tau0, mlist=mlist, confidence=confidence)
    
    # Apply LDEV scaling: σ_L(τ) = τ / √(10/3) · σ_MH(τ)
    scale = mhdev_result.tau ./ sqrt(10/3)
    ldev_vals = scale .* mhdev_result.deviation
    
    # Scale confidence intervals accordingly
    ci_scaled = mhdev_result.ci .* scale
    
    # Create result structure  
    result = DeviationResult(
        mhdev_result.tau, ldev_vals, mhdev_result.edf, ci_scaled, mhdev_result.alpha, mhdev_result.neff,
        mhdev_result.tau0, mhdev_result.N, "ldev", mhdev_result.confidence
    )
    
    return result
end

"""
    totdev(phase_data, tau0; mlist=nothing, confidence=0.683)

Compute Total deviation from phase data.
Total deviation uses all overlapping samples with detrending and symmetric reflection.

# Arguments
- `phase_data`: Phase data vector (seconds)
- `tau0`: Sampling interval (seconds)
- `mlist`: Averaging factors (optional, defaults to octave spacing with ≥2m points)
- `confidence`: Confidence level for intervals (default: 0.683)

# Returns
Total deviation (dimensionless frequency stability measure)
"""
function totdev(phase_data::AbstractVector{T}, tau0::Real;
                mlist::Union{Nothing,AbstractVector{Int}}=nothing,
                confidence::Real=0.683) where T<:Real
    
    # Validate inputs
    x = validate_phase_data(phase_data)
    tau0 = validate_tau0(tau0)
    N = length(x)
    
    # Default m_list: octave-spaced values with ≥2m points available (exact MATLAB logic)
    if mlist === nothing
        mlist = [2^k for k in 0:floor(Int, log2(N/2))]
    end
    
    # Remove linear frequency drift (detrending)
    x_drift_removed = detrend_linear(x)
    
    # Symmetric reflection about endpoints
    # MATLAB: x_left = 2*x_drift_removed(1) - x_drift_removed(2:N-1);
    #         x_right = 2*x_drift_removed(end) - x_drift_removed(end-1:-1:2);
    x_left = 2*x_drift_removed[1] .- x_drift_removed[2:N-1]
    x_right = 2*x_drift_removed[end] .- x_drift_removed[end-1:-1:2]
    x_star = [x_left; x_drift_removed; x_right]
    offset = length(x_left)
    
    # Initialize outputs
    tau = mlist .* tau0
    totdev_vals = fill(NaN, length(mlist))
    rawvar = fill(NaN, length(mlist))
    edf_vals = fill(NaN, length(mlist))
    neff = fill(0, length(mlist))
    
    # Noise identification (placeholder)
    alpha = noise_id(x, mlist, "phase")
    
    # Compute raw total deviation for each m
    valid_indices = Int[]
    for (k, m) in enumerate(mlist)
        # MATLAB: i_all = 1:(3*N - 2*m - 4);
        #         center = i_all + m;
        #         valid = (center >= 1) & (center <= N);
        i_all = 1:(3*N - 2*m - 4)
        center = i_all .+ m
        valid_mask = (center .>= 1) .& (center .<= N)
        
        if !any(valid_mask)
            continue
        end
        
        push!(valid_indices, k)
        i = i_all[valid_mask]
        
        # Second differences on extended data
        # MATLAB: d2 = x_star(offset + i + 2*m) - 2*x_star(offset + i + m) + x_star(offset + i);
        d2 = x_star[offset .+ i .+ 2*m] - 2*x_star[offset .+ i .+ m] + x_star[offset .+ i]
        
        # Total variance calculation
        D = sum(d2.^2)
        den = 2 * (N - 2) * (m * tau0)^2
        rawvar[k] = D / den
        
        neff[k] = length(d2)
    end
    
    # Trim to valid results only
    if isempty(valid_indices)
        # Return empty results if no valid calculations
        result = DeviationResult(
            T[], T[], T[], Matrix{T}(undef, 0, 2), T[], Int[],
            tau0, N, "totdev", confidence
        )
        return result
    end
    
    # Keep only valid results
    tau = tau[valid_indices]
    rawvar = rawvar[valid_indices]
    mlist_valid = mlist[valid_indices]
    neff = neff[valid_indices]
    alpha = alpha[valid_indices]
    edf_vals = edf_vals[valid_indices]
    
    # Bias correction (simplified - in full implementation would use bias_correction function)
    # For now, assume bias correction factors B ≈ 1 (placeholder)
    B = ones(T, length(rawvar))  # Placeholder - should be bias_correction(alpha, 'totvar', tau, T)
    totdev_vals = sqrt.(rawvar ./ B)
    
    # EDF calculation (placeholder)
    for k in eachindex(mlist_valid)
        edf_vals[k] = neff[k]  # Simple approximation
    end
    
    # Compute confidence intervals
    ci = compute_ci(totdev_vals, edf_vals, confidence, alpha, neff)
    
    # Create result structure
    result = DeviationResult(
        tau, totdev_vals, edf_vals, ci, alpha, neff,
        tau0, N, "totdev", confidence
    )
    
    return result
end

"""
    hdev(phase_data, tau0; mlist=nothing, confidence=0.683)

Compute Hadamard deviation from phase data.
Hadamard deviation uses overlapping third differences for robust frequency drift rejection.

# Arguments
- `phase_data`: Phase data vector (seconds)
- `tau0`: Sampling interval (seconds)
- `mlist`: Averaging factors (optional, defaults to octave spacing with ≥4m points)
- `confidence`: Confidence level for intervals (default: 0.683)

# Returns
Hadamard deviation (dimensionless frequency stability measure)

# References
NIST SP1065 Sections 5.2.8–5.2.9
"""
function hdev(phase_data::AbstractVector{T}, tau0::Real;
              mlist::Union{Nothing,AbstractVector{Int}}=nothing,
              confidence::Real=0.683) where T<:Real
    
    # Validate inputs
    x = validate_phase_data(phase_data)
    tau0 = validate_tau0(tau0)
    N = length(x)
    
    # Default m_list: octave-spaced values with ≥4m points available (exact MATLAB logic)
    if mlist === nothing
        mlist = [2^k for k in 0:floor(Int, log2(N/4))]
    end
    
    # Initialize outputs
    tau = mlist .* tau0
    hdev_vals = fill(NaN, length(mlist))
    edf_vals = fill(NaN, length(mlist))
    neff = fill(0, length(mlist))
    
    # Noise identification (placeholder)
    alpha = noise_id(x, mlist, "phase")
    
    # Compute overlapping HDEV using third differences
    for (k, m) in enumerate(mlist)
        L = N - 3*m
        if L <= 0
            break
        end
        neff[k] = L
        
        # Third difference: x(n+3m) - 3x(n+2m) + 3x(n+m) - x(n)
        # MATLAB: d3 = x(1+3*m:N) - 3*x(1+2*m:N-m) + 3*x(1+m:N-2*m) - x(1:L);
        d3 = x[1+3*m:N] - 3*x[1+2*m:N-m] + 3*x[1+m:N-2*m] - x[1:L]
        
        # SP1065: σ²_H(τ) = ⟨(Δ³x)²⟩ / (6·τ²)
        hvar = mean(d3.^2) / (6 * tau[k]^2)
        hdev_vals[k] = sqrt(hvar)
        
        # EDF calculation (placeholder)
        edf_vals[k] = L  # Simple approximation for now
    end
    
    # Compute confidence intervals
    ci = compute_ci(hdev_vals, edf_vals, confidence, alpha, neff)
    
    # Create result structure
    result = DeviationResult(
        tau, hdev_vals, edf_vals, ci, alpha, neff,
        tau0, N, "hdev", confidence
    )
    
    return result
end

# Multiple dispatch for hdev different return patterns
function hdev(phase_data::AbstractVector, tau0::Real, ::Val{2}; kwargs...)
    result = hdev(phase_data, tau0; kwargs...)
    return result.tau, result.deviation
end

function hdev(phase_data::AbstractVector, tau0::Real, ::Val{3}; kwargs...)
    result = hdev(phase_data, tau0; kwargs...)
    return result.tau, result.deviation, result.edf
end

function hdev(phase_data::AbstractVector, tau0::Real, ::Val{4}; kwargs...)
    result = hdev(phase_data, tau0; kwargs...)
    return result.tau, result.deviation, result.edf, result.ci
end

function hdev(phase_data::AbstractVector, tau0::Real, ::Val{5}; kwargs...)
    result = hdev(phase_data, tau0; kwargs...)
    return result.tau, result.deviation, result.edf, result.ci, result.alpha
end

"""
    mtotdev(phase_data, tau0; mlist=nothing, confidence=0.683)

Compute Modified total deviation from phase data.
Modified total deviation uses half-average detrending method and uninverted even reflection.

# Arguments
- `phase_data`: Phase data vector (seconds)
- `tau0`: Sampling interval (seconds)
- `mlist`: Averaging factors (optional, defaults to octave spacing with ≥3m points)
- `confidence`: Confidence level for intervals (default: 0.683)

# Returns
Modified total deviation (dimensionless frequency stability measure)

# References
NIST SP1065 Section 5.2.12
"""
function mtotdev(phase_data::AbstractVector{T}, tau0::Real;
                 mlist::Union{Nothing,AbstractVector{Int}}=nothing,
                 confidence::Real=0.683) where T<:Real
    
    # Validate inputs
    x = validate_phase_data(phase_data)
    tau0 = validate_tau0(tau0)
    N = length(x)
    
    # Default m_list: octave-spaced values with ≥3m points available (exact MATLAB logic)
    if mlist === nothing
        mlist = [2^k for k in 0:floor(Int, log2(N/3))]
    end
    
    # Initialize outputs
    tau = mlist .* tau0
    mtotdev_vals = fill(NaN, length(mlist))
    Mvar = fill(NaN, length(mlist))
    edf_vals = fill(NaN, length(mlist))
    neff = fill(0, length(mlist))
    
    # Noise identification (placeholder)
    alpha = noise_id(x, mlist, "phase")
    
    # Compute MTOTVAR for each m
    valid_indices = Int[]
    for (k, m) in enumerate(mlist)
        nsubs = N - 3*m + 1
        neff[k] = nsubs
        
        if nsubs < 1
            continue
        end
        
        push!(valid_indices, k)
        outer_sum = zero(T)
        
        for n in 1:nsubs
            # Extract 3m phase points
            seq = x[n:n+3*m-1]
            half_n = 3*m / 2
            
            # Detrend using half-average method
            if m == 1
                first_half = seq[1]
                last_half = seq[3]
                slope = (last_half - first_half) / (2 * tau0)
            else
                first_half = mean(seq[1:floor(Int, half_n)])
                last_half = mean(seq[floor(Int, half_n)+1:end])
                slope = (last_half - first_half) / (half_n * tau0)
            end
            
            # Remove linear trend
            seq_detrended = seq - slope * tau0 * T.(0:3*m-1)
            
            # Extend by uninverted even reflection
            ext = [seq_detrended[end:-1:1]; seq_detrended; seq_detrended[end:-1:1]]
            
            # Calculate second differences using cumsum
            cs = cumsum([zero(T); ext])
            avg1 = (cs[1+m:6*m+m] - cs[1:6*m]) ./ m
            avg2 = (cs[1+2*m:6*m+2*m] - cs[1+m:6*m+m]) ./ m
            avg3 = (cs[1+3*m:6*m+3*m] - cs[1+2*m:6*m+2*m]) ./ m
            
            # Second differences
            d2 = avg3 - 2*avg2 + avg1
            
            # Accumulate variance
            outer_sum += sum(d2.^2) / (6 * m)
        end
        
        # Normalize for Modified Total variance
        Mvar[k] = outer_sum / (2 * (m * tau0)^2 * nsubs)
    end
    
    # Trim to valid results only
    if isempty(valid_indices)
        # Return empty results if no valid calculations
        result = DeviationResult(
            T[], T[], T[], Matrix{T}(undef, 0, 2), T[], Int[],
            tau0, N, "mtotdev", confidence
        )
        return result
    end
    
    # Keep only valid results
    tau = tau[valid_indices]
    Mvar = Mvar[valid_indices]
    mlist_valid = mlist[valid_indices]
    neff = neff[valid_indices]
    alpha = alpha[valid_indices]
    edf_vals = edf_vals[valid_indices]
    
    # Convert variance to deviation
    mtotdev_vals = sqrt.(Mvar)
    
    # EDF calculation (placeholder)
    for k in eachindex(mlist_valid)
        edf_vals[k] = neff[k]  # Simple approximation
    end
    
    # Compute confidence intervals
    ci = compute_ci(mtotdev_vals, edf_vals, confidence, alpha, neff)
    
    # Create result structure
    result = DeviationResult(
        tau, mtotdev_vals, edf_vals, ci, alpha, neff,
        tau0, N, "mtotdev", confidence
    )
    
    return result
end

# Multiple dispatch for mtotdev different return patterns
function mtotdev(phase_data::AbstractVector, tau0::Real, ::Val{2}; kwargs...)
    result = mtotdev(phase_data, tau0; kwargs...)
    return result.tau, result.deviation
end

function mtotdev(phase_data::AbstractVector, tau0::Real, ::Val{3}; kwargs...)
    result = mtotdev(phase_data, tau0; kwargs...)
    return result.tau, result.deviation, result.edf
end

function mtotdev(phase_data::AbstractVector, tau0::Real, ::Val{4}; kwargs...)
    result = mtotdev(phase_data, tau0; kwargs...)
    return result.tau, result.deviation, result.edf, result.ci
end

function mtotdev(phase_data::AbstractVector, tau0::Real, ::Val{5}; kwargs...)
    result = mtotdev(phase_data, tau0; kwargs...)
    return result.tau, result.deviation, result.edf, result.ci, result.alpha
end

"""
    htotdev(phase_data, tau0; mlist=nothing, confidence=0.683)

Compute Hadamard total deviation from phase data.
Hadamard total deviation uses SP1065 detrending method and matches allantools/Stable32 results.

# Arguments
- `phase_data`: Phase data vector (seconds)
- `tau0`: Sampling interval (seconds)
- `mlist`: Averaging factors (optional, defaults to octave spacing with ≥3m points)
- `confidence`: Confidence level for intervals (default: 0.683)

# Returns
Hadamard total deviation (dimensionless frequency stability measure)

# References
NIST SP1065 Section 5.2.14
"""
function htotdev(phase_data::AbstractVector{T}, tau0::Real;
                 mlist::Union{Nothing,AbstractVector{Int}}=nothing,
                 confidence::Real=0.683) where T<:Real
    
    # Validate inputs
    x = validate_phase_data(phase_data)
    tau0 = validate_tau0(tau0)
    N = length(x)
    
    # Convert phase to fractional frequency
    y = diff(x) ./ tau0
    Ny = length(y)
    
    # Default m_list: octave-spaced values with ≥3m points available
    if mlist === nothing
        mlist = [2^k for k in 0:floor(Int, log2(Ny/3))]
    end
    
    # Initialize outputs
    tau = mlist .* tau0
    htotdev_vals = fill(NaN, length(mlist))
    edf_vals = fill(NaN, length(mlist))
    neff = fill(0, length(mlist))
    
    # Noise identification (placeholder)
    alpha = noise_id(x, mlist, "phase")
    
    # Compute HTOTVAR for each m
    valid_indices = Int[]
    for (idx, m) in enumerate(mlist)
        # Special case: m=1 uses overlapping HDEV
        if m == 1
            hdev_result = hdev(x, tau0, mlist=[1])
            if !isempty(hdev_result.deviation)
                htotdev_vals[idx] = hdev_result.deviation[1]
                push!(valid_indices, idx)
            end
            continue
        end
        
        # Number of subsequences
        n_iterations = Ny - 3*m + 1
        if n_iterations < 1
            continue
        end
        
        push!(valid_indices, idx)
        neff[idx] = n_iterations
        
        # Accumulator for variance
        dev_sum = zero(T)
        
        # Loop over subsequences
        for i in 0:(n_iterations-1)
            # Extract 3m points
            xs = y[i+1:i+3*m]
            
            # Remove linear trend using half-average method
            half1_idx = floor(Int, 3*m/2)
            half2_idx = ceil(Int, 3*m/2)
            
            # Calculate means of first and second halves
            mean1 = mean(xs[1:half1_idx])
            mean2 = mean(xs[half2_idx+1:end])  # Fixed: added +1
            
            # Calculate slope based on odd/even
            if mod(3*m, 2) == 1  # 3m is odd
                slope = (mean2 - mean1) / (0.5*(3*m-1) + 1)
            else  # 3m is even
                slope = (mean2 - mean1) / (0.5*3*m)
            end
            
            # Detrend the sequence
            x0 = zeros(T, length(xs))
            for j in 0:(length(xs)-1)
                x0[j+1] = xs[j+1] - slope * (j - floor(3*m/2))
            end
            
            # Extend by uninverted even reflection
            xstar = [x0[end:-1:1]; x0; x0[end:-1:1]]
            
            # Calculate Hadamard differences using cumsum for efficiency
            cs = cumsum([zero(T); xstar])
            j_indices = 0:(6*m-1)
            
            # Calculate three m-point window sums
            sum1 = cs[j_indices.+m.+1] - cs[j_indices.+1]
            sum2 = cs[j_indices.+2*m.+1] - cs[j_indices.+m.+1]
            sum3 = cs[j_indices.+3*m.+1] - cs[j_indices.+2*m.+1]
            
            # Convert to means
            xmean1 = sum1 ./ m
            xmean2 = sum2 ./ m
            xmean3 = sum3 ./ m
            
            # Hadamard differences
            H = xmean3 - 2*xmean2 + xmean1
            
            # Sum of squares normalized by 6m
            squaresum = sum(H.^2) / (6*m)
            dev_sum += squaresum
        end
        
        # Final normalization per equation (29): divide by 6*(N-3m+1)
        htotvar = dev_sum / (6 * n_iterations)
        htotdev_vals[idx] = sqrt(htotvar)
    end
    
    # Trim to valid results only
    if isempty(valid_indices)
        # Return empty results if no valid calculations
        result = DeviationResult(
            T[], T[], T[], Matrix{T}(undef, 0, 2), T[], Int[],
            tau0, N, "htotdev", confidence
        )
        return result
    end
    
    # Keep only valid results
    tau = tau[valid_indices]
    htotdev_vals = htotdev_vals[valid_indices]
    mlist_valid = mlist[valid_indices]
    neff = neff[valid_indices]
    alpha = alpha[valid_indices]
    edf_vals = edf_vals[valid_indices]
    
    # EDF calculation (placeholder)
    for k in eachindex(mlist_valid)
        edf_vals[k] = neff[k]  # Simple approximation
    end
    
    # Bias correction (simplified - in full implementation would use bias_correction function)
    # For now, assume bias correction factors B ≈ 1 (placeholder)
    B = ones(T, length(htotdev_vals))  # Placeholder
    for k in eachindex(mlist_valid)
        if mlist_valid[k] != 1  # Skip m=1 since it uses HDEV
            htotdev_vals[k] = htotdev_vals[k] * sqrt(B[k])
        end
    end
    
    # Compute confidence intervals
    ci = compute_ci(htotdev_vals, edf_vals, confidence, alpha, neff)
    
    # Create result structure
    result = DeviationResult(
        tau, htotdev_vals, edf_vals, ci, alpha, neff,
        tau0, N, "htotdev", confidence
    )
    
    return result
end

# Multiple dispatch for htotdev different return patterns
function htotdev(phase_data::AbstractVector, tau0::Real, ::Val{2}; kwargs...)
    result = htotdev(phase_data, tau0; kwargs...)
    return result.tau, result.deviation
end

function htotdev(phase_data::AbstractVector, tau0::Real, ::Val{3}; kwargs...)
    result = htotdev(phase_data, tau0; kwargs...)
    return result.tau, result.deviation, result.edf
end

function htotdev(phase_data::AbstractVector, tau0::Real, ::Val{4}; kwargs...)
    result = htotdev(phase_data, tau0; kwargs...)
    return result.tau, result.deviation, result.edf, result.ci
end

function htotdev(phase_data::AbstractVector, tau0::Real, ::Val{5}; kwargs...)
    result = htotdev(phase_data, tau0; kwargs...)
    return result.tau, result.deviation, result.edf, result.ci, result.alpha
end

"""
    mhtotdev(phase_data, tau0; mlist=nothing, confidence=0.683)

Compute Modified Hadamard total deviation from phase data.
Modified Hadamard total deviation uses linear detrending and symmetric reflection.

# Arguments
- `phase_data`: Phase data vector (seconds)
- `tau0`: Sampling interval (seconds)
- `mlist`: Averaging factors (optional, defaults to octave spacing with ≥4m points)
- `confidence`: Confidence level for intervals (default: 0.683)

# Returns
Modified Hadamard total deviation (dimensionless frequency stability measure)

# References
NIST SP1065 Sections 5.2.12 & 5.2.14
"""
function mhtotdev(phase_data::AbstractVector{T}, tau0::Real;
                  mlist::Union{Nothing,AbstractVector{Int}}=nothing,
                  confidence::Real=0.683) where T<:Real
    
    # Validate inputs
    x = validate_phase_data(phase_data)
    tau0 = validate_tau0(tau0)
    N = length(x)
    
    # Default m_list: octave-spaced values with ≥4m points available (exact MATLAB logic)
    if mlist === nothing
        mlist = [2^k for k in 0:floor(Int, log2(N/4))]
    end
    
    # Initialize outputs
    tau = mlist .* tau0
    mhtotdev_vals = fill(NaN, length(mlist))
    MHvar = fill(NaN, length(mlist))
    edf_vals = fill(NaN, length(mlist))  # No published EDF model
    neff = N .- 4*mlist .+ 1
    
    # Noise identification (placeholder)
    alpha = noise_id(x, mlist, "phase")
    
    # Compute MHTOTDEV for each m
    valid_indices = Int[]
    for (k, m) in enumerate(mlist)
        nsubs = neff[k]
        if nsubs < 1
            continue
        end
        
        push!(valid_indices, k)
        total_sum = zero(T)
        
        for n in 1:nsubs
            # Extract phase segment (3m+1 points for 3m frequency samples)
            phase_seg = x[n:n+3*m]
            
            # Linear detrending of phase data using our detrend_linear function
            phase_detrended = detrend_linear(phase_seg)
            
            # Symmetric reflection of phase data
            ext = [phase_detrended[end:-1:1]; phase_detrended; phase_detrended[end:-1:1]]
            
            # Third difference on phase data
            L = length(ext) - 3*m
            d3 = ext[1:L] - 3*ext[1+m:L+m] + 3*ext[1+2*m:L+2*m] - ext[1+3*m:L+3*m]
            
            # Moving average
            S = cumsum([zero(T); d3])
            if length(S) > m
                avg = S[m+1:end] - S[1:end-m]
                block_var = mean(avg.^2) / (6 * m^2)
            else
                block_var = zero(T)
            end
            total_sum += block_var
        end
        
        # Store average variance
        MHvar[k] = total_sum / nsubs
        
        # Convert to deviation and normalize by tau
        mhtotdev_vals[k] = sqrt(MHvar[k]) / tau[k]
    end
    
    # Trim to valid results only
    if isempty(valid_indices)
        # Return empty results if no valid calculations
        result = DeviationResult(
            T[], T[], T[], Matrix{T}(undef, 0, 2), T[], Int[],
            tau0, N, "mhtotdev", confidence
        )
        return result
    end
    
    # Keep only valid results
    tau = tau[valid_indices]
    mhtotdev_vals = mhtotdev_vals[valid_indices]
    mlist_valid = mlist[valid_indices]
    neff = neff[valid_indices]
    alpha = alpha[valid_indices]
    edf_vals = edf_vals[valid_indices]  # Will remain NaN - no published EDF model
    
    # Compute confidence intervals
    ci = compute_ci(mhtotdev_vals, edf_vals, confidence, alpha, neff)
    
    # Create result structure
    result = DeviationResult(
        tau, mhtotdev_vals, edf_vals, ci, alpha, neff,
        tau0, N, "mhtotdev", confidence
    )
    
    return result
end

# Multiple dispatch for mhtotdev different return patterns
function mhtotdev(phase_data::AbstractVector, tau0::Real, ::Val{2}; kwargs...)
    result = mhtotdev(phase_data, tau0; kwargs...)
    return result.tau, result.deviation
end

function mhtotdev(phase_data::AbstractVector, tau0::Real, ::Val{3}; kwargs...)
    result = mhtotdev(phase_data, tau0; kwargs...)
    return result.tau, result.deviation, result.edf
end

function mhtotdev(phase_data::AbstractVector, tau0::Real, ::Val{4}; kwargs...)
    result = mhtotdev(phase_data, tau0; kwargs...)
    return result.tau, result.deviation, result.edf, result.ci
end

function mhtotdev(phase_data::AbstractVector, tau0::Real, ::Val{5}; kwargs...)
    result = mhtotdev(phase_data, tau0; kwargs...)
    return result.tau, result.deviation, result.edf, result.ci, result.alpha
end