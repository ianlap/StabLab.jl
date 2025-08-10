# Time interval error functions for StabLab.jl

"""
    tie(data, tau0::Real=1.0; m_list=nothing, confidence=0.683)

Time Interval Error RMS - computes root-mean-square of time interval errors.

TIE measures phase deviations over different observation intervals τ = m·τ₀.
For each tau, computes RMS of (max(phase) - min(phase)) within sliding windows.

# Arguments
- `data`: Phase data vector (seconds)
- `tau0`: Sampling interval (seconds)
- `m_list`: Averaging factors (default: octave-spaced from 1 to N/3)
- `confidence`: Confidence level for intervals (default: 0.683 for 1-sigma)

# Returns
DeviationResult with TIE RMS values at each tau

# References
- ITU-T Recommendation G.810
- NIST SP1065 Section 5.15
"""
function tie(data::Vector{T}, tau0::Real=1.0; 
             m_list::Union{Nothing,Vector{Int}}=nothing,
             confidence::T=T(0.683)) where T<:Real
    
    # Validate inputs
    N = length(data)
    validate_phase_data(data)
    
    # Generate tau values if not provided
    if m_list === nothing
        m_list = default_m_list(N)
    end
    
    # Preallocate output arrays
    n_taus = length(m_list)
    tau = zeros(T, n_taus)
    deviation = zeros(T, n_taus)
    edf = fill(NaN, n_taus)
    ci = fill(NaN, n_taus, 2)
    alpha = fill(-2, n_taus)  # Assume white PM noise
    neff = zeros(Int, n_taus)
    
    # Compute TIE for each tau
    for (idx, m) in enumerate(m_list)
        tau[idx] = m * tau0
        
        # Number of pairs (AllanTools algorithm)
        n_pairs = N - m
        if n_pairs < 1
            deviation[idx] = NaN
            neff[idx] = 0
            continue
        end
        
        # Compute max-min for each pair (i, i+m) - AllanTools method
        tie_values = zeros(T, n_pairs)
        for i in 1:n_pairs
            pair_max = max(data[i], data[i+m])
            pair_min = min(data[i], data[i+m])
            tie_values[i] = pair_max - pair_min
        end
        
        # RMS of TIE values
        deviation[idx] = sqrt(mean(tie_values .^ 2))
        neff[idx] = n_pairs
    end
    
    return DeviationResult(tau, deviation, edf, ci, alpha, neff, 
                          T(tau0), N, "tie", confidence)
end

"""
    mtie(data, tau0::Real=1.0; m_list=nothing, confidence=0.683)

Maximum Time Interval Error - finds maximum phase deviation within observation windows.

MTIE is the maximum peak-to-peak phase variation observed over all possible 
windows of duration τ = m·τ₀. Critical for telecom timing requirements.

# Arguments
- `data`: Phase data vector (seconds)
- `tau0`: Sampling interval (seconds)
- `m_list`: Averaging factors (default: octave-spaced from 1 to N/3)
- `confidence`: Confidence level for intervals (default: 0.683)

# Returns
DeviationResult with MTIE values at each tau

# Algorithm
Uses efficient sliding window approach:
1. For each tau, slide window across phase data
2. Track min/max within each window position
3. Return maximum peak-to-peak deviation observed

# References
- ITU-T Recommendation G.810/G.811
- Bregni, "Measurement of Maximum Time Interval Error for Telecom Networks"
"""
function mtie(data::Vector{T}, tau0::Real=1.0; 
              m_list::Union{Nothing,Vector{Int}}=nothing,
              confidence::T=T(0.683)) where T<:Real
    
    # Validate inputs
    N = length(data)
    validate_phase_data(data)
    
    # Generate tau values if not provided
    if m_list === nothing
        m_list = default_m_list(N)
    end
    
    # Preallocate output arrays
    n_taus = length(m_list)
    tau = zeros(T, n_taus)
    deviation = zeros(T, n_taus)
    edf = fill(NaN, n_taus)
    ci = fill(NaN, n_taus, 2)
    alpha = fill(-2, n_taus)  # Assume white PM noise
    neff = zeros(Int, n_taus)
    
    # Compute MTIE for each tau
    for (idx, m) in enumerate(m_list)
        tau[idx] = m * tau0
        
        # AllanTools uses window size mj+1, and n_windows = N - mj
        window_size = m + 1
        n_windows = N - m  # Number of valid window positions
        if n_windows < 1 || window_size > N
            deviation[idx] = NaN
            neff[idx] = 0
            continue
        end
        
        # Efficient MTIE computation
        if m < 100  # Small window - use simple approach
            max_tie = zero(T)
            for i in 1:n_windows
                # Window from i to i+m (inclusive), size = m+1
                window = @view data[i:i+m]
                tie = maximum(window) - minimum(window)
                max_tie = max(max_tie, tie)
            end
            deviation[idx] = max_tie
        else  # Large window - use optimized algorithm
            # Initialize with first window (size m+1)
            curr_max = maximum(@view data[1:window_size])
            curr_min = minimum(@view data[1:window_size])
            max_tie = curr_max - curr_min
            
            # Slide window efficiently
            for i in 2:n_windows
                # Check if we need to recalculate max/min
                leaving = data[i-1]  # Element leaving the window
                entering = data[i+m]  # Element entering the window
                
                if leaving == curr_max
                    curr_max = maximum(@view data[i:i+m])
                elseif entering > curr_max
                    curr_max = entering
                end
                
                if leaving == curr_min
                    curr_min = minimum(@view data[i:i+m])
                elseif entering < curr_min
                    curr_min = entering
                end
                
                tie = curr_max - curr_min
                max_tie = max(max_tie, tie)
            end
            deviation[idx] = max_tie
        end
        
        neff[idx] = n_windows
    end
    
    return DeviationResult(tau, deviation, edf, ci, alpha, neff, 
                          T(tau0), N, "mtie", confidence)
end

"""
    pdev(data, tau0::Real=1.0; m_list=nothing, confidence=0.683)

Parabolic deviation - evaluates uncertainty of omega-averaged frequency.

PDEV uses parabolic weighting to remove linear frequency drift, making it
useful for characterizing oscillators with significant aging or drift.

# Mathematical Definition
For m > 1:
    σ²_PDEV(mτ₀) = 72/((N-2m)(mτ₀)²) × Σᵢ[Σₖ((m-1)/2 - k)(xᵢ₊ₖ - xᵢ₊ₖ₊ₘ)]²

For m = 1, PDEV equals ADEV.

# Arguments
- `data`: Phase data vector (seconds)
- `tau0`: Sampling interval (seconds)
- `m_list`: Averaging factors (default: octave-spaced from 1 to N/3)
- `confidence`: Confidence level for intervals (default: 0.683)

# Returns
DeviationResult with parabolic deviation values

# References
- Vernotte et al., "The Parabolic Variance (PVAR): A Wavelet Variance Based on the Least-Square Fit"
- IEEE Std 1139-2008
"""
function pdev(data::Vector{T}, tau0::Real=1.0; 
              m_list::Union{Nothing,Vector{Int}}=nothing,
              confidence::T=T(0.683)) where T<:Real
    
    # Validate inputs
    N = length(data)
    validate_phase_data(data)
    
    # Generate tau values if not provided
    if m_list === nothing
        m_list = default_m_list(N)
    end
    
    # Preallocate output arrays
    n_taus = length(m_list)
    tau = zeros(T, n_taus)
    deviation = zeros(T, n_taus)
    edf = fill(NaN, n_taus)
    ci = fill(NaN, n_taus, 2)
    alpha = fill(-2, n_taus)  # Placeholder
    neff = zeros(Int, n_taus)
    
    # Compute PDEV for each tau
    for (idx, m) in enumerate(m_list)
        tau[idx] = m * tau0
        
        if m == 1
            # For m=1, PDEV equals ADEV
            # Use simple Allan variance formula
            n = N - 2
            if n < 1
                deviation[idx] = NaN
                neff[idx] = 0
                continue
            end
            
            # Second differences
            sum_sq = zero(T)
            for i in 1:n
                diff = data[i+2] - 2*data[i+1] + data[i]
                sum_sq += diff^2
            end
            
            deviation[idx] = sqrt(sum_sq / (2 * n)) / tau[idx]
            neff[idx] = n
        else
            # Parabolic deviation for m > 1
            M = N - 2*m
            if M < 1
                deviation[idx] = NaN
                neff[idx] = 0
                continue
            end
            
            # Compute parabolic weighted sums
            sum_sq = zero(T)
            for i in 0:M-1
                # Inner sum with parabolic weights
                inner_sum = zero(T)
                for k in 0:m-1
                    weight = (m-1)/2.0 - k
                    inner_sum += weight * (data[i+k+1] - data[i+k+m+1])
                end
                sum_sq += inner_sum^2
            end
            
            # Scale by normalization factor
            variance = 72 * sum_sq / (M * m^4 * tau[idx]^2)
            # Guard against numerical errors
            if variance < 0
                deviation[idx] = NaN
            else
                deviation[idx] = sqrt(variance)
            end
            neff[idx] = M
        end
    end
    
    return DeviationResult(tau, deviation, edf, ci, alpha, neff, 
                          T(tau0), N, "pdev", confidence)
end

"""
    theo1(data, tau0::Real=1.0; m_list=nothing, confidence=0.683)

THEO1 deviation - two-sample variance with improved confidence and extended averaging range.

THEO1 provides better confidence intervals than Allan variance for white noise
and extends to larger averaging factors.

# Mathematical Definition
    σ²_THEO1(mτ₀) = 1/((mτ₀)²(N-m)) × Σᵢ Σ_δ (1/(m/2-δ)) × 
                    [(xᵢ - xᵢ₋δ₊ₘ/₂) + (xᵢ₊ₘ - xᵢ₊δ₊ₘ/₂)]²

Where m must be even and 10 ≤ m ≤ N-1.

# Arguments
- `data`: Phase data vector (seconds)
- `tau0`: Sampling interval (seconds)
- `m_list`: Averaging factors (must be even, default: even octave-spaced)
- `confidence`: Confidence level for intervals (default: 0.683)

# Returns
DeviationResult with THEO1 deviation values

# References
- NIST SP1065 eq (30) page 29
- Howe et al., "Theo1: Characterization of Very Long-Term Frequency Stability"
"""
function theo1(data::Vector{T}, tau0::Real=1.0; 
               m_list::Union{Nothing,Vector{Int}}=nothing,
               confidence::T=T(0.683)) where T<:Real
    
    # Validate inputs
    N = length(data)
    validate_phase_data(data)
    
    # Generate even tau values if not provided
    if m_list === nothing
        m_list = default_m_list(N)
        # Ensure all m values are even and >= 10
        m_list = [m for m in m_list if m >= 10 && m % 2 == 0]
        if isempty(m_list)
            m_list = [10]  # Minimum valid value
        end
    else
        # Validate that all m values are even
        if any(m % 2 != 0 for m in m_list)
            error("THEO1 requires all m values to be even")
        end
    end
    
    # Preallocate output arrays
    n_taus = length(m_list)
    tau = zeros(T, n_taus)
    deviation = zeros(T, n_taus)
    edf = fill(NaN, n_taus)
    ci = fill(NaN, n_taus, 2)
    alpha = fill(-2, n_taus)  # Placeholder
    neff = zeros(Int, n_taus)
    
    # Compute THEO1 for each tau
    for (idx, m) in enumerate(m_list)
        tau[idx] = m * tau0
        
        if m > N - 1
            deviation[idx] = NaN
            neff[idx] = 0
            continue
        end
        
        # THEO1 computation
        sum_total = zero(T)
        n_terms = 0
        m_half = div(m, 2)
        
        for i in 1:N-m
            inner_sum = zero(T)
            for delta in 0:m_half-1
                weight = 1.0 / (m_half - delta)
                term1 = data[i] - data[i - delta + m_half]
                term2 = data[i + m] - data[i + delta + m_half]
                inner_sum += weight * (term1 + term2)^2
                n_terms += 1
            end
            sum_total += inner_sum
        end
        
        # Apply normalization with bias correction factor
        bias_factor = 0.75  # From NIST references
        variance = sum_total / (bias_factor * (N - m) * tau[idx]^2)
        deviation[idx] = sqrt(variance)
        neff[idx] = n_terms
    end
    
    return DeviationResult(tau, deviation, edf, ci, alpha, neff, 
                          T(tau0), N, "theo1", confidence)
end

# Helper function for generating masks (for future TIE/MTIE mask support)
"""
    generate_itu_mask(mask_type::String, tau_range::Vector{T}) where T<:Real

Generate ITU-T recommended masks for TIE/MTIE limits.

# Arguments
- `mask_type`: One of "G.811", "G.812", "G.813", "G.823", "G.824", "G.825"
- `tau_range`: Vector of tau values (seconds)

# Returns
Vector of mask limit values corresponding to tau_range

# References
- ITU-T Recommendations G.810 series
"""
function generate_itu_mask(mask_type::String, tau_range::Vector{T}) where T<:Real
    # This is a placeholder for ITU mask generation
    # Full implementation would include all ITU-T timing masks
    
    mask = zeros(T, length(tau_range))
    
    if mask_type == "G.811"
        # Primary reference clock mask
        for (i, tau) in enumerate(tau_range)
            if tau < 1
                mask[i] = 3e-9
            elseif tau < 100
                mask[i] = 3e-9 * sqrt(tau)
            else
                mask[i] = 3e-8
            end
        end
    elseif mask_type == "G.812"
        # Synchronization supply unit mask
        for (i, tau) in enumerate(tau_range)
            if tau < 1
                mask[i] = 1e-8
            elseif tau < 100
                mask[i] = 1e-8 * sqrt(tau)
            else
                mask[i] = 1e-7
            end
        end
    else
        error("Mask type $mask_type not implemented")
    end
    
    return mask
end