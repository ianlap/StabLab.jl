# Confidence interval calculations

"""
    compute_ci(deviation, edf, confidence, alpha, neff)

Compute confidence intervals for deviation values.
Simple implementation using normal approximation for now.
"""
function compute_ci(deviation::AbstractVector{T}, edf::AbstractVector{T}, 
                   confidence::T, alpha::AbstractVector{T}, 
                   neff::AbstractVector{Int}) where T<:Real
    
    n = length(deviation)
    ci = Matrix{T}(undef, n, 2)
    
    # Simple approximation: ±10% bounds
    # TODO: Implement proper EDF-based confidence intervals
    for i in 1:n
        if isfinite(deviation[i])
            lower = deviation[i] * 0.9
            upper = deviation[i] * 1.1
            ci[i, :] = [lower, upper]
        else
            ci[i, :] = [NaN, NaN]
        end
    end
    
    return ci
end