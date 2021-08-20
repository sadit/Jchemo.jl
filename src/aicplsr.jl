"""
    dfplsr_cg(X, y; nlv, reorth = true)
Compute the model complexity (df) of PLSR models with the CGLS algorithm.
* `X` : X-data.
* `y` : Univariate Y-data.
* `nlv` : Nb. latent variables (LVs).
* `reorth` : If `true`, a Gram-Schmidt reorthogonalization of the normal equation 
    residual vectors is done.

The number of degrees of freedom (df) of the model is returned for 0, 1, ..., nlv LVs.

`X` and `y` are internally centered. The models are computed with an intercept. 

## References

Hansen, P.C., 1998. Rank-Deficient and Discrete Ill-Posed Problems, Mathematical Modeling and Computation. 
Society for Industrial and Applied Mathematics. https://doi.org/10.1137/1.9780898719697

Hansen, P.C., 2008. Regularization Tools version 4.0 for Matlab 7.3. 
Numer Algor 46, 189–194. https://doi.org/10.1007/s11075-007-9136-9

Lesnoff, M., Roger, J.M., Rutledge, D.N., Submitted. Monte Carlo methods for estimating 
Mallows’s Cp and AIC criteria for PLSR models. Illustration on agronomic spectroscopic NIR data. 
Journal of Chemometrics.
""" 
function dfplsr_cg(X, y; nlv, reorth = true)
    F = cglsr(X, y; nlv = nlv, reorth = reorth, filt = true).F
    df = [1 ; vec(1 .+ sum(F, dims = 1))]
    (df = df,)
end

"""
    aicplsr(X, y; nlv, reorth = true, filt = false)
Compute the Akaike's (AIC) and Mallows's (Cp) criteria for univariate PLSR models.
* `X` : X-data.
* `y` : Univariate Y-data.
* `nlv` : Nb. latent variables (LVs).
* `reorth` : If `true`, a Gram-Schmidt reorthogonalization of the normal equation 
    residual vectors is done.

For the methodolgy, see Hansen 1998, 2008 and Lesnoff et al. Submitted.

`X` and `y` are internally centered. The models are computed with an intercept. 

## References

Hansen, P.C., 1998. Rank-Deficient and Discrete Ill-Posed Problems, Mathematical Modeling and Computation. 
Society for Industrial and Applied Mathematics. https://doi.org/10.1137/1.9780898719697

Hansen, P.C., 2008. Regularization Tools version 4.0 for Matlab 7.3. 
Numer Algor 46, 189–194. https://doi.org/10.1007/s11075-007-9136-9

Lesnoff, M., Roger, J.M., Rutledge, D.N., Submitted. Monte Carlo methods for estimating 
Mallows’s Cp and AIC criteria for PLSR models. Illustration on agronomic spectroscopic NIR data. 
Journal of Chemometrics
""" 
function aicplsr(X, y; nlv, correct = true)
    X = ensure_mat(X)
    n = size(X, 1)
    p = size(X, 2)
    nlv = min(nlv, n, p)  
    res = gridscorelv(X, y, X, y;
        fun = plskern, score = ssr, nlv = 0:nlv)
    zssr = res.y1
    df = dfplsr_cg(X, y, nlv = nlv, reorth = true).df
    df_ssr = n .- df
    # For Cp, unbiased estimate of sigma2 
    # ----- Cp1: From a low biased model
    # Not stable with dfcov and nlv too large compared to best model !!
    # If df stays below .95 * n, this corresponds
    # to the maximal model (nlv)
    # Option 2 gives in general results
    # very close to those of option 1,
    # but can give poor results with dfcov
    # when nlv is set too large to the best model
    k = maximum(findall(df .<= .5 * n))
    s2_1 = zssr[k] / df_ssr[k]
    # ----- Cp2: FPE-like
    # s2 is estimated from the model under evaluation
    # Used in Kraemer & Sugiyama 2011 Eq.5-6
    s2_2 = zssr ./ df_ssr
    ct = ones(nlv + 1)
    correct ? ct .= n ./ (n .- df .- 2) : nothing
    ct[(df .> n) .| (ct .<= 0)] .= NaN 
    # For safe predictions when df stabilizes and fluctuates
    ct[df .> .8 * n] .= NaN
    # End
    u = findall(isnan.(ct)) 
    if length(u) > 0
        ct[minimum(u):(nlv + 1)] .= NaN
    end
    aic = n * log.(zssr) + 2 * (df .+ 1) .* ct
    cp1 = zssr .+ 2 * s2_1 * df .* ct
    cp2 = zssr .+ 2 * s2_2 .* df .* ct
    cp1 = cp1 / n
    cp2 = cp2 / n
    res = (aic = aic, cp1 = cp1, cp2 = cp2)
    znlv = 0:nlv
    tab = DataFrame(nlv = znlv, n = fill(n, nlv + 1), df = df, ct = ct, ssr = zssr)
    crit = hcat(tab, DataFrame(res))
    opt = map(x -> findmin(x[isnan.(x) .== 0])[2] - 1, res)
    delta = map(x -> x .- findmin(x[isnan.(x) .== 0])[1], res)                  # Differences "Delta"
    w = map(x -> exp.(-x / 2) / sum(exp.(-x[isnan.(x) .== 0] / 2)), delta)      # AIC odel weights   
    delta = reduce(hcat, delta)
    w = reduce(hcat, w)
    nam = [:aic, :cp1, :cp2]
    delta = DataFrame(delta, nam)
    insertcols!(delta, 1, :nlv => znlv)
    w = DataFrame(w, nam)
    insertcols!(w, 1, :nlv => znlv)
    (crit = crit, opt = opt, delta = delta, w = w)
end
