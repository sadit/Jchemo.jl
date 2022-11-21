struct Pls
    Tx::Matrix{Float64}
    Ty::Matrix{Float64}
    Px::Matrix{Float64}
    Py::Matrix{Float64}
    Rx::Matrix{Float64}
    Ry::Matrix{Float64}    
    Wx::Matrix{Float64}
    Wy::Matrix{Float64}
    TTx::Vector{Float64}
    TTy::Vector{Float64}
    delta::Vector{Float64}    
    bscales::Vector{Float64}    
    xmeans::Vector{Float64}
    xscales::Vector{Float64}
    ymeans::Vector{Float64}
    yscales::Vector{Float64}
    weights::Vector{Float64}
end


"""
    pls(X, Y, weights = ones(nro(X)); nlv,
        bscal = "none", scal = false)
    pls!(X::Matrix, Y::Matrix, weights = ones(nro(X)); nlv,
        bscal = "none", scal = false)
Canonical partial least squares regression (Canonical PLS)
* `X` : First block (matrix) of data.
* `Y` : Second block (matrix) of data.
* `weights` : Weights of the observations (rows). 
    Internally normalized to sum to 1. 
* `nlv` : Nb. latent variables (LVs = scores T) to compute.
* `bscal` : Type of block scaling (`"none"`, `"frob"`). 
    See functions `blockscal`.
* `scal` : Boolean. If `true`, each column of `X` and `Y` 
    is scaled by its uncorrected standard deviation 
    (before the block scaling).

Canonical PLS with the NIPALS algorithm (Wold 1984, Tenenhaus 1998 chap.11), 
where the two blocks `X` and `X` play a symmetric role.  
This PLS is referred to as PLS-W2A (i.e. Wold PLS mode A) in Wegelin 2000.
After each step of scores computation, X is deflated by the tx scores, 
and Y by the ty scores.

## References

Tenenhaus, M., 1998. La régression PLS: théorie et pratique. Editions Technip, Paris.

Wegelin, J.A., 2000. A Survey of Partial Least Squares (PLS) Methods, with Emphasis 
on the Two-Block Case (No. 371). University of Washington, Seattle, Washington, USA.

Wold, S., Ruhe, A., Wold, H., Dunn, III, W.J., 1984. The Collinearity Problem in Linear 
Regression. The Partial Least Squares (PLS) Approach to Generalized Inverses. 
SIAM Journal on Scientific and Statistical Computing 5, 735–743. 
https://doi.org/10.1137/0905052

## Examples
```julia
zX = [1. 2 3 4 5 7 100; 4 1 6 7 12 13 28; 12 5 6 13 3 1 5; 27 18 7 6 2 0 12 ; 
    12 11 28 7 1 25 2 ; 2 3 7 1 0 7 26 ; 14 12 101 4 3 7 10 ; 8 7 6 5 4 3 -100] 
n = nro(zX) 
X = zX[:, 1:4]
Y = zX[:, 5:7]

fm = pls(X, Y; nlv = 3)
pnames(fm)

res = summary(fm, X, Y)
pnames(res)
```
"""
function pls(X, Y, weights = ones(nro(X)); nlv,
        bscal = "none", scal = false)
    pls!(copy(ensure_mat(X)), copy(ensure_mat(Y)), weights; nlv = nlv,
        bscal = bscal, scal = scal)
end

function pls!(X::Matrix, Y::Matrix, weights = ones(nro(X)); nlv,
        bscal = "none", scal = false)
    n, p = size(X)
    q = nco(Y)
    nlv = min(nlv, n, p)
    weights = mweight(weights)
    D = Diagonal(weights)
    xmeans = colmean(X, weights) 
    ymeans = colmean(Y, weights)   
    xscales = ones(p)
    yscales = ones(q)
    if scal 
        xscales .= colstd(X, weights)
        yscales .= colstd(Y, weights)
        cscale!(X, xmeans, xscales)
        cscale!(Y, ymeans, yscales)
    else
        center!(X, xmeans)
        center!(Y, ymeans)
    end
    bscal == "none" ? bscales = ones(2) : nothing
    if bscal == "frob"
        normx = fnorm(X, weights)
        normy = fnorm(Y, weights)
        X ./= normx
        Y ./= normy
        bscales = [normx; normy]
    end
    # Pre-allocation
    XtY = similar(X, p, q)
    Tx = similar(X, n, nlv)
    Ty = copy(Tx)
    Wx = similar(X, p, nlv)
    Wy = similar(X, q, nlv)
    Px = copy(Wx)
    Py = copy(Wy)
    TTx = similar(X, nlv)
    TTy = copy(TTx)
    tx   = similar(X, n)
    ty = copy(tx)
    dtx  = copy(tx)
    dty = copy(tx)   
    wx  = similar(X, p)
    wy  = similar(X, q)
    px   = copy(wx)
    py   = copy(wy)
    delta = copy(TTx)
    # End
    @inbounds for a = 1:nlv
        XtY .= X' * (D * Y)
        U, d, V = svd!(XtY) 
        delta[a] = d[1]
        # X
        wx .= U[:, 1]
        mul!(tx, X, wx)
        dtx .= weights .* tx
        ttx = dot(tx, dtx)
        mul!(px, X', dtx)
        px ./= ttx
        # Y
        wy .= V[:, 1]
        # Same as:                        
        # mul!(wy, Y', dtx)
        # wy ./= norm(wy)
        # End
        mul!(ty, Y, wy)
        dty .= weights .* ty
        tty = dot(ty, dty)
        mul!(py, Y', dty)
        py ./= tty
        # Deflation
        X .-= tx * px'
        Y .-= ty * py'
        # End
        Px[:, a] .= px
        Py[:, a] .= py
        Tx[:, a] .= tx
        Ty[:, a] .= ty
        Wx[:, a] .= wx
        Wy[:, a] .= wy
        TTx[a] = ttx
        TTy[a] = tty
     end
     Rx = Wx * inv(Px' * Wx)
     Ry = Wy * inv(Py' * Wy)
     Pls(Tx, Ty, Px, Py, Rx, Ry, Wx, Wy, TTx, TTy, delta, 
         bscales, xmeans, xscales, ymeans, yscales, weights)
end

""" 
    transform(object::Pls, X, Y; nlv = nothing)
Compute latent variables (LVs = scores T) from a fitted model and (X, Y)-data.
* `object` : The fitted model.
* `X` : X-data for which components (LVs) are computed.
* `Y` : Y-data for which components (LVs) are computed.
* `nlv` : Nb. LVs to compute. If nothing, it is the maximum number
    from the fitted model.
""" 
function transform(object::Pls, X, Y; nlv = nothing)
    X = ensure_mat(X)
    Y = ensure_mat(Y)   
    a = nco(object.Tx)
    isnothing(nlv) ? nlv = a : nlv = min(nlv, a)
    Tx = cscale(X, object.xmeans, object.xscales) * vcol(object.Rx, 1:nlv)
    Ty = cscale(Y, object.ymeans, object.yscales) * vcol(object.Ry, 1:nlv)
    (Tx = Tx, Ty)
end

"""
    summary(object::Pls, X, Y)
Summarize the fitted model.
* `object` : The fitted model.
* `X` : The X-data that was used to fit the model.
* `Y` : The Y-data that was used to fit the model.
""" 
function Base.summary(object::Pls, X::Union{Vector, Matrix, DataFrame},
        Y::Union{Vector, Matrix, DataFrame})
    X = ensure_mat(X)
    Y = ensure_mat(Y)
    n, nlv = size(object.Tx)
    X = cscale(X, object.xmeans, object.xscales)
    Y = cscale(Y, object.ymeans, object.yscales)
    ttx = object.TTx 
    tty = object.TTy 
    ## Explained variances
    # X
    sstot = fnorm(X, object.weights)^2
    tt_adj = vec(sum(object.Px.^2, dims = 1)) .* ttx
    pvar = tt_adj / sstot
    cumpvar = cumsum(pvar)
    xvar = tt_adj / n    
    explvarx = DataFrame(nlv = 1:nlv, var = xvar, pvar = pvar, cumpvar = cumpvar)
    # Y
    sstot = fnorm(Y, object.weights)^2
    tt_adj = vec(sum(object.Py.^2, dims = 1)) .* tty
    pvar = tt_adj / sstot
    cumpvar = cumsum(pvar)
    xvar = tt_adj / n    
    explvary = DataFrame(nlv = 1:nlv, var = xvar, pvar = pvar, cumpvar = cumpvar)
    ## Correlation between block scores
    z = diag(corm(object.Tx, object.Ty, object.weights))
    cort2t = DataFrame(lv = 1:nlv, cor = z)
    ## Redundancies (Average correlations)
    z = rd(X, object.Tx, object.weights)
    rdx = DataFrame(lv = 1:nlv, rd = vec(z))
    z = rd(Y, object.Ty, object.weights)
    rdy = DataFrame(lv = 1:nlv, rd = vec(z))
    ## Correlation between block variables and block scores
    z = corm(X, object.Tx, object.weights)
    corx2t = DataFrame(z, string.("lv", 1:nlv))
    z = corm(Y, object.Ty, object.weights)
    cory2t = DataFrame(z, string.("lv", 1:nlv))
    ## End
    (explvarx = explvarx, explvary, cort2t, rdx, rdy, 
        corx2t, cory2t)
end
