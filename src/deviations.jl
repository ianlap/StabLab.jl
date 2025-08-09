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