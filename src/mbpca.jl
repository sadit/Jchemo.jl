struct Mbpca
    T::Array{Float64} 
    U::Array{Float64}
    W::Array{Float64}
    Tbl::Vector{Array{Float64}}
    Tb::Vector{Array{Float64}}
    Wbl::Vector{Array{Float64}}
    lb::Array{Float64}
    mu::Vector{Float64}
    bscales::Vector{Float64}
    xmeans::Vector{Vector{Float64}}
    xscales::Vector{Vector{Float64}}
    weights::Vector{Float64}
    niter::Vector{Float64}
end

"""
    mbpca(Xbl, weights = ones(nro(Xbl[1])); nlv,
        bscal = "none", tol = sqrt(eps(1.)), maxit = 200,
        scal = false)
    mbpca!(Xbl, weights = ones(nro(Xbl[1])); nlv,
        bscal = "none", tol = sqrt(eps(1.)), maxit = 200,
        scal = false)
Consensus principal components analysis (CPCA = MBPCA).
* `Xbl` : List (vector) of blocks (matrices) of X-data. 
    Each component of the list is a block.
* `weights` : Weights of the observations (rows). 
    Internally normalized to sum to 1. 
* `nlv` : Nb. latent variables (LVs = scores T) to compute.
* `bscal` : Type of block scaling (`"none"`, `"frob"`, `"mfa"`). 
    See functions `blockscal`.
* `tol` : Tolerance value for convergence.
* `maxit` : Maximum number of iterations.
* `scal` : Boolean. If `true`, each column of blocks in `Xbl` 
    is scaled by its uncorrected standard deviation 
    (before the block scaling).

The global scores are equal to the scores of the PCA of 
the horizontal concatenation X = [X1 X2 ... Xk].

The function returns several objects, in particular:
* `T` : The non normed global scores.
* `U` : The normed global scores.
* `W` : The global loadings.
* `Tbl` : The block scores (grouped by blocks, in the original scale).
* `Tb` : The block scores (grouped by LV, in the metric scale).
* `Wbl` : The block loadings.
* `lb` : The specific weights "lambda".
* `mu` : The sum of the specific weights (= eigen value of the global PCA).

Function `summary` returns: 
* `explvarx` : Proportion of the total inertia of X (sum of the squared norms of the 
    blocks) explained by each global score.
* `contr_block` : Contribution of each block to the global scores 
* `explX` : Proportion of the inertia of the blocks explained by each global score.
* `corx2t` : Correlation between the global scores and the original variables.  
* `cortb2t` : Correlation between the global scores and the block scores.
* `rv` : RV coefficient. 
* `lg` : Lg coefficient. 

## References
Mangamana, E.T., Cariou, V., Vigneau, E., Glèlè Kakaï, R.L., Qannari, E.M., 2019. 
Unsupervised multiblock data analysis: A unified approach and extensions. Chemometrics and 
Intelligent Laboratory Systems 194, 103856. https://doi.org/10.1016/j.chemolab.2019.103856

Westerhuis, J.A., Kourti, T., MacGregor, J.F., 1998. Analysis of multiblock and hierarchical 
PCA and PLS models. Journal of Chemometrics 12, 301–321. 
https://doi.org/10.1002/(SICI)1099-128X(199809/10)12:5<301::AID-CEM515>3.0.CO;2-S

## Examples
```julia
using JLD2
path_jdat = dirname(dirname(pathof(JchemoData)))
db = joinpath(path_jdat, "data/ham.jld2") 
@load db dat
pnames(dat) 

X = dat.X
group = dat.group
listbl = [1:11, 12:19, 20:25]
Xbl = mblock(X, listbl)
# "New" = first two rows of Xbl 
Xbl_new = mblock(X[1:2, :], listbl)

bscal = "frob"
fm = mbpca(Xbl; nlv = 4, bscal = bscal) ;
fm.U
fm.T
Jchemo.transform(fm, Xbl).T
Jchemo.transform(fm, Xbl_new).T 

res = summary(fm, Xbl) ;
fm.lb
rowsum(fm.lb)
fm.mu
res.explvarx
res.explX # = fm.lb if bscal = "frob"
rowsum(Matrix(res.explX))
res.contr_block
res.corx2t 
res.cortb2t
res.rv
```
"""
function mbpca(Xbl, weights = ones(nro(Xbl[1])); nlv, 
        bscal = "none", tol = sqrt(eps(1.)), maxit = 200,
        scal = false)
    nbl = length(Xbl)  
    zXbl = list(nbl, Matrix{Float64})
    @inbounds for k = 1:nbl
        zXbl[k] = copy(ensure_mat(Xbl[k]))
    end
    mbpca!(zXbl, weights; nlv = nlv, 
        bscal = bscal, tol = tol, maxit = maxit, 
        scal = scal)
end

function mbpca!(Xbl, weights = ones(nro(Xbl[1])); nlv,
        bscal = "none", tol = sqrt(eps(1.)), maxit = 200,
        scal = false)
    nbl = length(Xbl)
    n = nro(Xbl[1])
    weights = mweight(weights)
    sqrtw = sqrt.(weights)
    xmeans = list(nbl, Vector{Float64})
    xscales = list(nbl, Vector{Float64})
    p = fill(0, nbl)
    @inbounds for k = 1:nbl
        p[k] = nco(Xbl[k])
        xmeans[k] = colmean(Xbl[k], weights) 
        xscales[k] = ones(nco(Xbl[k]))
        if scal 
            xscales[k] = colstd(Xbl[k], weights)
            Xbl[k] = cscale(Xbl[k], xmeans[k], xscales[k])
        else
            Xbl[k] = center(Xbl[k], xmeans[k])
        end
    end
    bscal == "none" ? bscales = ones(nbl) : nothing
    if bscal == "frob"
        res = blockscal_frob(Xbl, weights) 
        bscales = res.bscales
        Xbl = res.X
    end
    if bscal == "mfa"
        res = blockscal_mfa(Xbl, weights) 
        bscales = res.bscales
        Xbl = res.X
    end
    # Row metric
    @inbounds for k = 1:nbl
        Xbl[k] = sqrtw .* Xbl[k]
    end
    # Pre-allocation
    U = similar(Xbl[1], n, nlv)
    W = similar(Xbl[1], nbl, nlv)
    Tbl = list(nbl, Matrix{Float64})
    for k = 1:nbl ; Tbl[k] = similar(Xbl[1], n, nlv) ; end
    Tb = list(nlv, Matrix{Float64})
    for a = 1:nlv ; Tb[a] = similar(Xbl[1], n, nbl) ; end
    Wbl = list(nbl, Matrix{Float64})
    for k = 1:nbl ; Wbl[k] = similar(Xbl[1], p[k], nlv) ; end
    u = similar(Xbl[1], n)
    tk = copy(u)
    w = similar(Xbl[1], nbl)
    lb = similar(Xbl[1], nbl, nlv)
    mu = similar(Xbl[1], nlv)
    niter = zeros(nlv)
    # End
    for a = 1:nlv
        X = reduce(hcat, Xbl)
        u .= nipals(X).u
        iter = 1
        cont = true
        while cont
            u0 = copy(u)
            for k = 1:nbl
                wk = Xbl[k]' * u    # = wktild
                dk = norm(wk)
                wk ./= dk           # = wk (= normed)
                tk .= Xbl[k] * wk 
                Tb[a][:, k] .= tk
                Tbl[k][:, a] .= (1 ./ sqrtw) .* Tb[a][:, k]
                Wbl[k][:, a] .= wk
                lb[k, a] = dk^2
            end
            res = nipals(Tb[a])
            u .= res.u 
            w .= res.v
            dif = sum((u .- u0).^2)
            iter = iter + 1
            if (dif < tol) || (iter > maxit)
                cont = false
            end
        end
        niter[a] = iter - 1
        U[:, a] .= u
        W[:, a] .= w
        mu[a] = res.sv^2  # = sum(lb)
        for k = 1:nbl
            Xbl[k] .-= u * (u' * Xbl[k])
        end
    end
    T = Diagonal(1 ./ sqrtw) * (sqrt.(mu)' .* U)
    Mbpca(T, U, W, Tbl, Tb, Wbl, lb, mu,
        bscales, xmeans, xscales, weights, niter)
end

""" 
    transform(object::Mbpca, Xbl; nlv = nothing)
Compute latent variables (LVs = scores T) from a fitted model and X-data.
* `object` : The fitted model.
* `Xbl` : A list (vector) of blocks (matrices) of X-data for which LVs are computed.
* `nlv` : Nb. LVs to compute.
""" 
function transform(object::Mbpca, Xbl; nlv = nothing)
    a = size(object.T, 2)
    isnothing(nlv) ? nlv = a : nlv = min(nlv, a)
    nbl = length(Xbl)
    m = size(Xbl[1], 1)
    zXbl = list(nbl, Matrix{Float64})
    Threads.@threads for k = 1:nbl
        zXbl[k] = cscale(Xbl[k], object.xmeans[k], object.xscales[k])
    end
    zXbl = blockscal(zXbl, object.bscales).X
    U = similar(zXbl[1], m, nlv)
    TB = similar(zXbl[1], m, nbl)
    Tbl = list(nbl, Matrix{Float64})
    for k = 1:nbl ; Tbl[k] = similar(zXbl[1], m, nlv) ; end
    u = similar(zXbl[1], m)
    tk = copy(u)
    for a = 1:nlv
        for k = 1:nbl
            tk .= zXbl[k] * object.Wbl[k][:, a]
            TB[:, k] .= tk
            Tbl[k][:, a] .= tk
        end
        u .= 1 / sqrt(object.mu[a]) * TB * object.W[:, a]
        U[:, a] .= u
        @inbounds for k = 1:nbl
            Px = sqrt(object.lb[k, a]) * object.Wbl[k][:, a]'
            zXbl[k] -= u * Px
        end
    end
    T = sqrt.(object.mu)' .* U
    (T = T, Tbl)
end

"""
    summary(object::Mbpca, Xbl)
Summarize the fitted model.
* `object` : The fitted model.
* `Xbl` : The X-data that was used to fit the model.
""" 
function Base.summary(object::Mbpca, Xbl)
    nbl = length(Xbl)
    nlv = size(object.T, 2)
    sqrtw = sqrt.(object.weights)
    zXbl = list(nbl, Matrix{Float64})
    Threads.@threads for k = 1:nbl
        zXbl[k] = cscale(Xbl[k], object.xmeans[k], object.xscales[k])
    end
    zXbl = blockscal(zXbl, object.bscales).X
    @inbounds for k = 1:nbl
        zXbl[k] .= sqrtw .* zXbl[k]
    end
    X = reduce(hcat, zXbl)
    # Explained_X
    sstot = zeros(nbl)
    @inbounds for k = 1:nbl
        sstot[k] = ssq(zXbl[k])
    end
    tt = colsum(object.lb)    
    pvar = tt / sum(sstot)
    cumpvar = cumsum(pvar)
    explvarx = DataFrame(lv = 1:nlv, var = tt, pvar = pvar, 
        cumpvar = cumpvar)
    # Contribution of the blocks to global scores = lb proportions (contrib)
    z = scale(object.lb, colsum(object.lb))
    contr_block = DataFrame(z, string.("lv", 1:nlv))
    # Proportion of inertia explained for each block (explained.X)
    # = object.lb if bscal = "frob" 
    z = scale((object.lb)', sstot)'
    explX = DataFrame(z, string.("lv", 1:nlv))
    # Correlation between the original variables and the global scores (globalcor)
    z = cor(X, object.U)  
    corx2t = DataFrame(z, string.("lv", 1:nlv))  
    # Correlation between the block scores and the global scores (cor.g.b)
    z = list(nlv, Matrix{Float64})
    @inbounds for a = 1:nlv
        z[a] = cor(object.Tb[a], object.U[:, a])
    end
    cortb2t = DataFrame(reduce(hcat, z), string.("lv", 1:nlv))
    # RV 
    X = vcat(zXbl, [sqrtw .* object.T])
    nam = [string.("block", 1:nbl) ; "T"]
    res = rv(X)
    zrv = DataFrame(res, nam)
    # Lg
    res = lg(X)
    zlg = DataFrame(res, nam)
    (explvarx = explvarx, contr_block, explX, 
        corx2t, cortb2t, rv = zrv, lg = zlg)
end







