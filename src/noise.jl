# Noise identification and characterization utilities
# Translated from MATLAB stablab/+stablab/noise_id.m

using Statistics

"""
    noise_id(x, m_list, data_type, dmin=0, dmax=2)

Dominant power-law noise estimator from time series data.

# Arguments
- `x`: Phase or frequency data (column vector)
- `m_list`: List of averaging factors (τ = m·τ₀)
- `data_type`: "phase" or "freq"  
- `dmin`: Minimum differencing depth (default = 0)
- `dmax`: Maximum differencing depth (default = 2)

# Returns
- `alpha_list`: Estimated α values at each τ

# Method
For each m, use lag-1 autocorrelation estimator when N_eff ≥ 30,
otherwise use fallback via B1 ratio and R(n) test.

# References
- NIST SP1065 Section 5.6
- Riley & Howe frequency stability analysis
"""
function noise_id(x::Vector{T}, m_list::Vector{Int}, data_type::String="phase", 
                 dmin::Int=0, dmax::Int=2) where T<:Real
    # Preprocess data: remove outliers and detrend
    x_clean = preprocess_x(x)
    alpha_list = fill(NaN, length(m_list))
    
    for (k, m) in enumerate(m_list)
        # Estimate number of usable points after averaging
        N_eff = floor(Int, length(x_clean) / m)
        
        try
            if N_eff >= 30
                # Use lag-1 ACF method
                alpha, _, _, _ = noise_id_lag1acf(x_clean, m, data_type, dmin, dmax)
            else
                # Use B1 ratio + R(n) fallback method
                alpha, _, _ = noise_id_b1rn(x_clean, m, data_type)
            end
            alpha_list[k] = round(Int, alpha)
        catch err
            @warn "Noise ID failed for m = $m: $(err)"
            alpha_list[k] = NaN
        end
    end
    
    return alpha_list
end

"""
    preprocess_x(x)

Remove outliers (>5σ) and linear trend from data.
"""
function preprocess_x(x::Vector{T}) where T<:Real
    x = vec(x)  # Ensure column vector
    
    # Remove outliers >5σ
    x_mean = mean(x)
    x_std = std(x)
    z_scores = abs.((x .- x_mean) ./ x_std)
    x_clean = x[z_scores .< 5.0]
    
    # Remove linear trend (frequency drift)
    return detrend_linear(x_clean)
end

"""
    noise_id_lag1acf(x, m, data_type, dmin=0, dmax=2)

Lag-1 autocorrelation function method for noise identification.

Returns (alpha, alpha_int, d, rho) where:
- alpha: Estimated noise exponent
- alpha_int: Rounded integer estimate  
- d: Final differencing order used
- rho: Fractional integration index
"""
function noise_id_lag1acf(x::Vector{T}, m::Int, data_type::String, 
                         dmin::Int=0, dmax::Int=2) where T<:Real
    # Step 1: Preprocess by data type
    if lowercase(data_type) == "phase"
        if m > 1
            x = x[1:m:end]  # Decimate
        end
        x = detrend_quadratic(x)  # Remove quadratic drift
    elseif lowercase(data_type) == "freq"
        N = floor(Int, length(x) / m) * m
        x = x[1:N]
        x = reshape(x, m, :)
        x = vec(mean(x, dims=1))  # Average in blocks
        x = detrend_linear(x)
    else
        error("data_type must be 'phase' or 'freq'")
    end
    
    # Step 2: Differencing loop
    d = 0
    while true
        r1 = compute_lag1_acf(x)  # Lag-1 autocorrelation
        rho = r1 / (1 + r1)       # Fractional integration index
        
        if d >= dmin && (rho < 0.25 || d >= dmax)
            p = -2 * (rho + d)    # Spectral slope
            alpha = p + 2 * (lowercase(data_type) == "phase" ? 1 : 0)
            alpha_int = round(Int, alpha)
            return (alpha, alpha_int, d, rho)
        else
            x = diff(x)
            d = d + 1
            if length(x) < 5
                error("Data too short after differencing")
            end
        end
    end
end

"""
    compute_lag1_acf(x)

Compute lag-1 autocorrelation coefficient.
"""
function compute_lag1_acf(x::Vector{T}) where T<:Real
    x = vec(x) .- mean(x)
    
    if all(x .== 0)
        return NaN
    end
    
    x0 = x[1:end-1]
    x1 = x[2:end]
    
    return sum(x0 .* x1) / sum(x .^ 2)
end

"""
    noise_id_b1rn(x_full, m, data_type)

B1 ratio and R(n) fallback method for noise identification.

Returns (alpha_int, mu_best, B1_obs) where:
- alpha_int: Integer noise exponent estimate
- mu_best: Best-fit slope parameter
- B1_obs: Observed B1 ratio
"""
function noise_id_b1rn(x_full::Vector{T}, m::Int, data_type::String) where T<:Real
    x_full = vec(x_full)
    
    if lowercase(data_type) == "phase"
        # Decimate and detrend phase data
        x_dec = x_full[1:m:end]
        x_dec = detrend_quadratic(x_dec)
        tau = m
        avar_val = simple_avar(x_dec, tau)
        N_avar = floor(Int, length(x_dec) - 2)
        
        # Classical variance of averaged differences
        dx = diff(x_full)
        N = floor(Int, length(dx) / m) * m
        if N < m
            return (NaN, NaN, NaN)
        end
        dx = dx[1:N]
        y_blocks = reshape(dx, m, :)
        y_avg = vec(mean(y_blocks, dims=1))
        var_classical = var(y_avg; corrected=false)
        
    elseif lowercase(data_type) == "freq"
        N = floor(Int, length(x_full) / m) * m
        if N < 2*m
            return (NaN, NaN, NaN)
        end
        x = reshape(x_full[1:N], m, :)
        y_avg = vec(mean(x, dims=1))
        y_avg = detrend_linear(y_avg)
        dy = diff(y_avg)
        var_classical = var(y_avg; corrected=false)
        avar_val = sum(dy .^ 2) / (2 * (length(y_avg) - 1))
        N_avar = length(y_avg)
    else
        error("Unsupported data_type: use 'phase' or 'freq'")
    end
    
    # Compute observed B1 ratio
    B1_obs = var_classical / avar_val
    
    # Define noise types (ordered from high to low μ for checking)
    mu_list = [1, 0, -1, -2]  # RWFM, FLFM, WHFM, WHPM
    alpha_list = [-2, -1, 0, 2]
    
    # Calculate theoretical B1 values
    b1_vals = [b1_theory(N_avar, mu) for mu in mu_list]
    
    # Decision boundaries using geometric means (NIST approach)
    mu_best = mu_list[end]  # Default to lowest μ
    alpha_int = alpha_list[end]
    
    for i in 1:length(mu_list)-1
        boundary = sqrt(b1_vals[i] * b1_vals[i+1])
        
        if B1_obs > boundary
            mu_best = mu_list[i]
            alpha_int = alpha_list[i]
            break
        end
    end
    
    # Refine α = 2 vs 1 using R(n) when needed (FLPM vs WHPM)
    if mu_best == -2 && lowercase(data_type) == "phase"
        adev_val = sqrt(avar_val)
        mdev_val = simple_mdev(x_full, tau, 1.0)
        Rn_obs = (mdev_val / adev_val)^2
        R_hi = rn_theory(m, 0)   # α = 2 (WHPM)
        R_lo = rn_theory(m, -1)  # α = 1 (FLPM)
        if Rn_obs > sqrt(R_hi * R_lo)
            alpha_int = 1  # Flicker PM
        else
            alpha_int = 2  # White PM
        end
    end
    
    return (alpha_int, mu_best, B1_obs)
end

"""
    b1_theory(N, mu)

Theoretical B1 values from slope μ.
"""
function b1_theory(N::Int, mu::Int)
    if mu == 2
        return N * (N + 1) / 6
    elseif mu == 1
        return N / 2
    elseif mu == 0
        return N * log(N) / (2 * (N - 1) * log(2))
    elseif mu == -1
        return 1.0
    elseif mu == -2
        return (N^2 - 1) / (1.5 * N * (N - 1))
    else
        return (N * (1 - N^mu)) / (2 * (N - 1) * (1 - 2^mu))
    end
end

"""
    rn_theory(af, b)

Theoretical R(n) values for noise classification.
"""
function rn_theory(af::Int, b::Int)
    if b == 0
        return af^(-1)  # White PM
    elseif b == -1
        avar = (1.038 + 3 * log(2 * π * 0.5 * af)) / (4 * π^2)
        mvar = 3 * log(256 / 27) / (8 * π^2)
        return mvar / avar  # Flicker PM
    else
        return 1.0
    end
end

"""
    simple_avar(x, m)

Simple Allan variance calculation without noise identification.
"""
function simple_avar(x::Vector{T}, m::Int) where T<:Real
    N = length(x)
    L = N - 2*m + 1
    if L <= 0
        return NaN
    end
    
    # Second differences: x(n+2m) - 2x(n+m) + x(n)
    d2 = x[1+2*m:N] - 2*x[1+m:N-m] + x[1:L]
    return mean(d2.^2) / (2 * m^2)
end

"""
    simple_mdev(x, m, tau0)

Simple Modified Allan deviation without calling full mdev function.
"""
function simple_mdev(x::Vector{T}, m::Int, tau0::Real) where T<:Real
    N = length(x)
    L = N - 3*m + 1
    if L <= 0
        return NaN
    end
    
    # Moving averages via cumulative sum
    S = cumsum([0; x])  # Prefix sum
    s1 = S[1+m:L+m]     - S[1:L]
    s2 = S[1+2*m:L+2*m] - S[1+m:L+m] 
    s3 = S[1+3*m:L+3*m] - S[1+2*m:L+2*m]
    d = s3 - 2*s2 + s1
    
    mvar = mean(d.^2) / (2 * m^2 * tau0^2)
    return sqrt(mvar)
end

"""
    detrend_quadratic(x)

Remove quadratic trend from data (for phase data).
"""
function detrend_quadratic(x::Vector{T}) where T<:Real
    N = length(x)
    if N < 3
        return x
    end
    
    # Design matrix for quadratic fit: [1, t, t²]
    t = collect(1:N)
    A = hcat(ones(N), t, t.^2)
    
    # Least squares fit and removal
    coeffs = A \ x
    trend = A * coeffs
    
    return x - trend
end