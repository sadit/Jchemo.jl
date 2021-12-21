"""
    plssimp(X, Y, weights = ones(size(X, 1)); nlv)
Partial Least Squares Regression (PLSR) with the SIMPLS algorithm (de Jong 1993).
* `X` : X-data.
* `Y` : Y-data.
* `weights` : Weights of the observations.
* `nlv` : Nb. latent variables (LVs) to compute.

The function has the following difference with the original 
algorithm of de Jong (2013):
* Scores T are not normed to 1.

For the weighting in PLS algorithms (`weights`), see in particular Schaal et al. 2002, 
Siccard & Sabatier 2006, Kim et al. 2011 and Lesnoff et al. 2020. See help of `plskern`. 

Vector `weights` is internally normalized to sum to 1.

`X` and `Y` are internally centered. The model is computed with an intercept.

## References

de Jong, S., 1993. SIMPLS: An alternative approach to partial least squares 
regression. Chemometrics and Intelligent Laboratory Systems 18, 251–263. 
https://doi.org/10.1016/0169-7439(93)85002-X

""" 
function plssimp(X, Y, weights = ones(size(X, 1)); nlv)
    plssimp!(copy(X), copy(Y), weights; nlv = nlv)
end

function plssimp!(X, Y, weights = ones(size(X, 1)); nlv)
    X = ensure_mat(X)
    Y = ensure_mat(Y)
    n = size(X, 1)
    p = size(X, 2)
    q = size(Y, 2)
    nlv = min(nlv, n, p)
    weights = mweights(weights)
    xmeans = colmeans(X, weights) 
    ymeans = colmeans(Y, weights)   
    X = center(X, xmeans)
    Y = center(Y, ymeans)
    D = Diagonal(weights)
    XtY = X' * (D * Y)                   # = Xd' * Y = X' * D * Y  (Xd = D * X   Very costly!!)
    # Pre-allocation
    T = similar(X, n, nlv)
    P = similar(X, p, nlv)
    W = copy(P)
    R = copy(P)
    C = similar(X, q, nlv)
    TT = similar(X, nlv)
    t   = similar(X, n)
    dt  = similar(X, n)   
    zp  = similar(X, p)
    r   = similar(X, p)
    c   = similar(X, q)
    tmp = similar(XtY)
    # End
    @inbounds for a = 1:nlv
        if a == 1
            tmp .= XtY
        else
            z = vcol(P, 1:(a - 1))
            tmp .= XtY .- z * inv(z' * z) * z' * XtY
        end
        u = svd!(tmp).U # = svd(tmp').U
        r .= u[:, 1]
        mul!(t, X, r)                 
        dt .= weights .* t            
        tt = dot(t, dt)               
        mul!(c, XtY', r)
        c ./= tt                      
        mul!(zp, X', dt) 
        P[:, a] .= zp ./ tt
        T[:, a] .= t
        R[:, a] .= r
        C[:, a] .= c
        TT[a] = tt
     end
     #B = R * inv(T' * D * T) * T' * D * Y
     Plsr(T, P, R, W, C, TT, xmeans, ymeans, weights, nothing)
end