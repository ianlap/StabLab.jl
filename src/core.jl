# Core utilities for StabLab

"""
    validate_phase_data(x)

Validate phase data input. Ensures data is finite, real, and numeric.
"""
function validate_phase_data(x::AbstractVector{T}) where T<:Real
    if !all(isfinite, x)
        throw(ArgumentError("Phase data must be finite"))
    end
    return vec(x)  # Ensure column vector
end

"""
    validate_tau0(tau0)

Validate sampling interval. Must be positive and finite.
"""
function validate_tau0(tau0::Real)
    if tau0 <= 0 || !isfinite(tau0)
        throw(ArgumentError("Sampling interval tau0 must be positive and finite"))
    end
    return tau0
end

"""
    default_m_list(N::Int)

Generate default averaging factors: octave-spaced values ensuring ≥2m points available.
"""
function default_m_list(N::Int)
    max_power = floor(Int, log2(N/2))
    return [2^k for k in 0:max_power]
end

"""
    detrend_linear(x)

Remove linear trend from data using least squares fit.
"""
function detrend_linear(x::AbstractVector{T}) where T<:Real
    n = length(x)
    if n < 2
        return copy(x)
    end
    
    # Create design matrix [ones(n) 1:n] for linear fit y = a + b*t
    A = [ones(T, n) T.(1:n)]
    
    # Least squares solution: coeffs = A \ x
    coeffs = A \ x
    
    # Remove trend: x - A*coeffs  
    return x - A * coeffs
end