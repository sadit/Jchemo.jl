struct MbplsrSo
    fm
    T::Matrix{Float64}
    fit::Matrix{Float64}
    b
end

"""
    mbplsr_so(X_bl, Y, weights = ones(size(X_bl, 1)); nlv,
        scal = false)
Multiblock sequentially orthogonalized PLSR (SO-PLSR).
* `X_bl` : List (vector) of blocks (matrices) of X-data. 
    Each component of the list is a block.
* `Y` : Y-data.
* `weights` : Weights of the observations (rows). 
* `nlv` : Nb. latent variables (LVs) to consider for each block. 
    Vector that must have a length equal to the nb. blocks.
* `scal` : Boolean. If `true`, each column of `X_bl` and `Y` 
    is scaled by its uncorrected standard deviation 
    (before the block scaling).

`weights` is internally normalized to sum to 1. 

## References
- Biancolillo et al. , 2015. Combining SO-PLS and linear discriminant analysis 
    for multi-block classification. Chemometrics and Intelligent Laboratory Systems, 
    141, 58-67.

- Biancolillo, A. 2016. Method development in the area of multi-block analysis focused on 
    food analysis. PhD. University of copenhagen.

- Menichelli et al., 2014. SO-PLS as an exploratory tool for path modelling. 
    Food Quality and Preference, 36, 122-134.

    ## Examples
```julia
using JLD2
mypath = dirname(dirname(pathof(JchemoData)))
db = joinpath(mypath, "data", "ham.jld2") 
@load db dat
pnames(dat) 

X = dat.X
y = dat.Y.c1
group = dat.group
listbl = [1:11, 12:19, 20:25]
X_bl = mblock(X, listbl)
# "New" = first two rows of X_bl 
X_bl_new = mblock(X[1:2, :], listbl)

nlv = [2; 1; 2]
fm = mbplsr_so(X_bl, y; nlv = nlv) ;
pnames(fm)
fm.T
Jchemo.transform(fm, X_bl_new)
[y Jchemo.predict(fm, X_bl).pred]
Jchemo.predict(fm, X_bl_new).pred
```
"""
function mbplsr_so(X_bl, Y, weights = ones(nro(X_bl[1])); nlv,
        scal = false)
    Y = ensure_mat(Y)
    n = size(X_bl[1], 1)
    q = size(Y, 2)   
    nbl = length(X_bl)
    weights = mweight(weights)
    D = Diagonal(weights)
    fm = list(nbl)
    pred = similar(X_bl[1], n, q)
    b = list(nbl)
    # First block
    fm[1] = plskern(X_bl[1], Y, weights; nlv = nlv[1], 
        scal = scal)
    T = fm[1].T
    pred .= Jchemo.predict(fm[1], X_bl[1]).pred
    b[1] = nothing
    # Other blocks
    if nbl > 1
        for i = 2:nbl
            b[i] = inv(T' * (D * T)) * T' * (D * X_bl[i])
            X = X_bl[i] - T * b[i]
            fm[i] = plskern(X, Y - pred, weights; nlv = nlv[i])
            T = hcat(T, fm[i].T)
            pred .+= Jchemo.predict(fm[i], X).pred 
        end
    end
    MbplsrSo(fm, T, pred, b)
end

""" 
    transform(object::MbplsrSo, X_bl)
Compute LVs ("scores" T) from a fitted model.
* `object` : The maximal fitted model.
* `X_bl` : A list (vector) of blocks (matrices) of X_bl-data for which LVs are computed.
""" 
function transform(object::MbplsrSo, X_bl)
    nbl = length(object.fm)
    T = transform(object.fm[1], X_bl[1])
    if nbl > 1
        @inbounds for i = 2:nbl
            X = X_bl[i] - T * object.b[i]
            T = hcat(T, transform(object.fm[i], X))
        end
    end
    T
end

"""
    predict(object::MbplsrSo, X_bl)
Compute Y-predictions from a fitted model.
* `object` : The fitted model.
* `X_bl` : A list (vector) of X-data for which predictions are computed.
""" 
function predict(object::MbplsrSo, X_bl)
    nbl = length(object.fm)
    T = transform(object.fm[1], X_bl[1])
    pred =  object.fm[1].ymeans' .+ T * object.fm[1].C'
    if nbl > 1
        @inbounds for i = 2:nbl
            X = X_bl[i] - T * object.b[i]
            zT = transform(object.fm[i], X)
            pred .+= object.fm[i].ymeans' .+ zT * object.fm[i].C'
            T = hcat(T, transform(object.fm[i], X))
        end
    end
    (pred = pred,)
end



