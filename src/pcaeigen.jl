"""
    pcaeigen(X, weights = ones(nro(X)); nlv, scal = false)
    pcaeigen!(X::Matrix, weights = ones(nro(X)); nlv, scal = false)
PCA by Eigen factorization.
* `X` : X-data (n, p).
* `weights` : Weights (n) of the observations. 
    Internally normalized to sum to 1.
* `nlv` : Nb. principal components (PCs).
* `scal` : Boolean. If `true`, each column of `X` is scaled
    by its uncorrected standard deviation.

Let us note D the (n, n) diagonal matrix of `weights`
and X the centered matrix in metric D. 
The function minimizes ||X - T * P'||^2  in metric D, by 
computing an Eigen factorization of X' * D * X. 

See `?pcasvd` for examples.
""" 
function pcaeigen(X, weights = ones(nro(X)); nlv, scal = false)
    pcaeigen!(copy(ensure_mat(X)), weights; nlv = nlv, scal = scal)
end

function pcaeigen!(X::Matrix, weights = ones(nro(X)); nlv, scal = false)
    n, p = size(X)
    nlv = min(nlv, n, p)
    weights = mweight(weights)
    xmeans = colmean(X, weights) 
    xscales = ones(p)
    if scal 
        xscales .= colstd(X, weights)
        cscale!(X, xmeans, xscales)
    else
        center!(X, xmeans)
    end
    sqrtw = sqrt.(weights)
    X .= Diagonal(sqrtw) * X
    res = eigen!(Symmetric(X' * X); sortby = x -> -abs(x)) 
    P = res.vectors[:, 1:nlv]
    eig = res.values[1:min(n, p)]
    eig[eig .< 0] .= 0
    sv = sqrt.(eig)
    T = Diagonal(1 ./ sqrtw) * X * P
    Pca(T, P, sv, xmeans, xscales, weights, nothing, nothing) 
end

"""
    pcaeigenk(X, weights = ones(nro(X)); nlv, scal = false)
    pcaeigenk!(X::Matrix, weights = ones(nro(X)); nlv, scal = false)
PCA by Eigen factorization of the kernel form (XX').
* `X` : X-data (n, p).
* `weights` : Weights (n) of the observations. 
    Internally normalized to sum to 1.
* `nlv` : Nb. principal components (PCs).
* `scal` : Boolean. If `true`, each column of `X` is scaled
    by its uncorrected standard deviation.

This is the "kernel cross-product" version of the PCA algorithm (e.g. Wu et al. 1997). 
For wide matrices (n << p, where p is the nb. columns) and n not too large, 
this algorithm can be much faster than the others.

Let us note D the (n, n) diagonal matrix of `weights`
and X the centered matrix in metric D. 
The function minimizes ||X - T * P'||^2  in metric D, by 
computing an Eigen factorization of D^(1/2) * X * X' D^(1/2).

See `?pcasvd` for examples.

## References
Wu, W., Massart, D.L., de Jong, S., 1997. The kernel PCA algorithms for wide data. 
Part I: Theory and algorithms. Chemometrics and Intelligent Laboratory Systems 36, 165-172.
https://doi.org/10.1016/S0169-7439(97)00010-5
""" 
function pcaeigenk(X, weights = ones(nro(X)); nlv, scal = false)
    pcaeigenk!(copy(ensure_mat(X)), weights; nlv = nlv, scal = scal)
end

function pcaeigenk!(X::Matrix, weights = ones(nro(X)); nlv, scal = false)
    n, p = size(X)
    nlv = min(nlv, n, p)
    weights = mweight(weights)
    xmeans = colmean(X, weights) 
    xscales = ones(p)
    if scal 
        xscales .= colstd(X, weights)
        cscale!(X, xmeans, xscales)
    else
        center!(X, xmeans)
    end
    sqrtw = sqrt.(weights)
    zX = Diagonal(sqrtw) * X
    res = eigen!(Symmetric(zX * zX'); sortby = x -> -abs(x))
    eig = res.values[1:min(n, p)]
    eig[eig .< 0] .= 0
    sv = sqrt.(eig)
    P = zX' * scale(res.vectors[:, 1:nlv], sv[1:nlv])
    T = X * P
    Pca(T, P, sv, xmeans, xscales, weights, nothing, nothing) 
end

