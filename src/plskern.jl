struct Plsr
    T::Matrix{Float64}
    P::Matrix{Float64}
    R::Matrix{Float64}
    W::Matrix{Float64}
    C::Matrix{Float64}
    TT::Vector{Float64}
    xmeans::Vector{Float64}
    xscales::Vector{Float64}
    ymeans::Vector{Float64}
    yscales::Vector{Float64}
    weights::Vector{Float64}
    niter::Union{Array{Float64}, Nothing}
end

"""
    plskern(X, Y, weights = ones(nro(X)); nlv,
        scal = false)
    plskern!(X::Matrix, Y::Matrix, weights = ones(nro(X)); nlv,
        scal = false)
Partial Least Squares Regression (PLSR) with the 
"improved kernel algorithm #1" (Dayal & McGegor, 1997).
* `X` : X-data (n, p).
* `Y` : Y-data (n, q).
* `weights` : Weights (n) of the observations. 
    Internally normalized to sum to 1.
* `nlv` : Nb. latent variables (LVs) to compute.
* `scal` : Boolean. If `true`, each column of `X` and `Y` 
    is scaled by its uncorrected standard deviation.
    
About the row-weighting in PLS algorithms (`weights`), see in particular Schaal et al. 2002, 
Siccard & Sabatier 2006, Kim et al. 2011, and Lesnoff et al. 2020. 

## References
Dayal, B.S., MacGregor, J.F., 1997. Improved PLS algorithms. 
Journal of Chemometrics 11, 73-85.

Kim, S., Kano, M., Nakagawa, H., Hasebe, S., 2011. Estimation of active 
pharmaceutical ingredients content using locally weighted partial 
least squares and statistical wavelength selection. Int. J. Pharm., 421, 269-274.

Lesnoff, M., Metz, M., Roger, J.M., 2020. Comparison of locally weighted 
PLS strategies for regression and discrimination on agronomic NIR Data. 
Journal of Chemometrics. e3209. 
https://onlinelibrary.wiley.com/doi/abs/10.1002/cem.3209

Schaal, S., Atkeson, C., Vijayamakumar, S. 2002. Scalable techniques 
from nonparametric statistics for the real time robot learning. 
Applied Intell., 17, 49-60.

Sicard, E. Sabatier, R., 2006. Theoretical framework for local PLS1 regression 
and application to a rainfall data set. Comput. Stat. Data Anal., 51, 1393-1410.

## Examples
```julia
using JchemoData, JLD2, CairoMakie
path_jdat = dirname(dirname(pathof(JchemoData)))
db = joinpath(path_jdat, "data/cassav.jld2") 
@load db dat
pnames(dat)

X = dat.X 
y = dat.Y.tbc
year = dat.Y.year
tab(year)
s = year .<= 2012
Xtrain = X[s, :]
ytrain = y[s]
Xtest = rmrow(X, s)
ytest = rmrow(y, s)

nlv = 15
fm = plskern(Xtrain, ytrain; nlv = nlv) ;
#fm = plsnipals(Xtrain, ytrain; nlv = nlv) ;
#fm = plsrosa(Xtrain, ytrain; nlv = nlv) ;
#fm = plssimp(Xtrain, ytrain; nlv = nlv) ;
pnames(fm)
fm.T

zcoef = Jchemo.coef(fm)
zcoef.int
zcoef.B
Jchemo.coef(fm; nlv = 7).B

Jchemo.transform(fm, Xtest)
Jchemo.transform(fm, Xtest; nlv = 7)

res = Jchemo.predict(fm, Xtest)
res.pred
rmsep(res.pred, ytest)
plotxy(vec(res.pred), ytest; color = (:red, .5),
    bisect = true, xlabel = "Prediction", 
    ylabel = "Observed").f    

res = Jchemo.predict(fm, Xtest; nlv = 1:2)
res.pred[1]
res.pred[2]

res = summary(fm, Xtrain) ;
pnames(res)
z = res.explvarx
lines(z.nlv, z.cumpvar,
    axis = (xlabel = "Nb. LVs", ylabel = "Prop. Explained X-Variance"))
```
""" 
function plskern(X, Y, weights = ones(nro(X)); nlv, 
        scal = false)
    plskern!(copy(ensure_mat(X)), copy(ensure_mat(Y)), weights; 
        nlv = nlv, scal = scal)
end

function plskern!(X::Matrix, Y::Matrix, weights = ones(nro(X)); 
        nlv, scal = false)
    n, p = size(X)
    q = nco(Y)
    nlv = min(n, p, nlv)
    weights = mweight(weights)
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
    D = Diagonal(weights)
    XtY = X' * (D * Y)                   # = Xd' * Y = X' * D * Y  (Xd = D * X   Very costly!!)
    #XtY = X' * (weights .* Y)           # Can create OutOfMemory errors for very large matrices
    # Pre-allocation
    T = similar(X, n, nlv)
    W = similar(X, p, nlv)
    P = copy(W)
    R = copy(P)
    C = similar(X, q, nlv)
    TT = similar(X, nlv)
    t   = similar(X, n)
    dt  = similar(X, n)   
    zp  = similar(X, p)
    w   = similar(X, p)
    r   = similar(X, p)
    c   = similar(X, q)
    tmp = similar(XtY) # = XtY_approx
    # End
    @inbounds for a = 1:nlv
        if q == 1
            w .= vcol(XtY, 1)
            w ./= norm(w)
        else
            w .= svd(XtY).U[:, 1]
        end                                  
        r .= w
        if a > 1
            @inbounds for j = 1:(a - 1)
                r .-= dot(w, vcol(P, j)) .* vcol(R, j)    
            end
        end                   
        mul!(t, X, r)                 # t = X * r
        dt .= weights .* t            # dt = D * t
        tt = dot(t, dt)               # tt = t' * dt = t' * D * t 
        mul!(c, XtY', r)
        c ./= tt                      # c = XtY' * r / tt
        mul!(zp, X', dt)              # zp = (D * X)' * t = X' * (D * t)
        XtY .-= mul!(tmp, zp, c')     # XtY = XtY - zp * c' ; deflation of the kernel matrix 
        P[:, a] .= zp ./ tt           # ==> the metric applied to covariance is applied outside the loop,
        T[:, a] .= t                  # conversely to other algorithms such as nipals
        W[:, a] .= w
        R[:, a] .= r
        C[:, a] .= c
        TT[a] = tt
     end
     Plsr(T, P, R, W, C, TT, xmeans, xscales, ymeans, 
         yscales, weights, nothing)
end

""" 
    transform(object::Plsr, X; nlv = nothing)
Compute latent variables (LVs = scores T) from a fitted model and a matrix X.
* `object` : The fitted model.
* `X` : Matrix (m, p) for which LVs are computed.
* `nlv` : Nb. LVs to consider.
""" 
function transform(object::Plsr, X; nlv = nothing)
    X = ensure_mat(X)
    a = nco(object.T)
    isnothing(nlv) ? nlv = a : nlv = min(nlv, a)
    T = cscale(X, object.xmeans, object.xscales) * vcol(object.R, 1:nlv)
    # Could be cscale! but changes X
    # If too heavy ==> Makes summary!
    T
end

"""
    coef(object::Union{Plsr, Pcr}; nlv = nothing)
Compute the X b-coefficients of a model fitted with `nlv` LVs.
* `object` : The fitted model.
* `nlv` : Nb. LVs to consider.

If X is (n, p) and Y is (n, q), the returned object `B` is a matrix (p, q). 
If `nlv` = 0, `B` is a matrix of zeros.
The returned object `int` is the intercept.
""" 
function coef(object::Union{Plsr, Pcr}; nlv = nothing)
    a = nco(object.T)
    isnothing(nlv) ? nlv = a : nlv = min(nlv, a)
    beta = object.C[:, 1:nlv]'
    W = Diagonal(object.yscales)
    B = Diagonal(1 ./ object.xscales) * vcol(object.R, 1:nlv) * beta * W
    # 'int': No correction is needed 
    # since ymeans, xmeans and B are in the original scale 
    int = object.ymeans' .- object.xmeans' * B
    (B = B, int = int)
end

"""
    predict(object::Union{Plsr, Pcr}, X; nlv = nothing)
Compute Y-predictions from a fitted model.
* `object` : The fitted model.
* `X` : X-data for which predictions are computed.
* `nlv` : Nb. LVs, or collection of nb. LVs, to consider. 
""" 
function predict(object::Union{Plsr, Pcr}, X; nlv = nothing)
    X = ensure_mat(X)
    a = nco(object.T)
    isnothing(nlv) ? nlv = a : nlv = (max(0, minimum(nlv)):min(a, maximum(nlv)))
    le_nlv = length(nlv)
    pred = list(le_nlv, Matrix{Float64})
    @inbounds  for i = 1:le_nlv
        z = coef(object; nlv = nlv[i])
        pred[i] = z.int .+ X * z.B
    end 
    le_nlv == 1 ? pred = pred[1] : nothing
    (pred = pred,)
end

"""
    summary(object::Plsr, X)
Summarize the fitted model.
* `object` : The fitted model.
* `X` : The X-data that was used to fit the model.
""" 
function Base.summary(object::Plsr, X::Union{Vector, Matrix, DataFrame})
    X = ensure_mat(X)
    n, nlv = size(object.T)
    X = cscale(X, object.xmeans, object.xscales)
    # Could be cscale! but changes X
    # If too heavy ==> Makes summary!
    sstot = sum(object.weights' * (X.^2)) # = frob(X, object.weights)^2 
    tt = object.TT
    tt_adj = colsum(object.P.^2) .* tt    # tt_adj[a] = p[a]'p[a] * tt[a]
    pvar = tt_adj / sstot
    cumpvar = cumsum(pvar)
    xvar = tt_adj / n    
    explvarx = DataFrame(nlv = 1:nlv, var = xvar, pvar = pvar, cumpvar = cumpvar)     
    (explvarx = explvarx,)
end


