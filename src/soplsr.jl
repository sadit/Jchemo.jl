struct Soplsr
    fm
    T::Matrix{Float64}
    fit::Matrix{Float64}
    b
end

"""
    soplsr(Xbl, Y, weights = ones(size(Xbl, 1)); nlv,
        scal = false)
Multiblock sequentially orthogonalized PLSR (SO-PLSR).
* `Xbl` : List (vector) of blocks (matrices) of X-data. 
    Each component of the list is a block.
* `Y` : Y-data.
* `weights` : Weights of the observations (rows). 
    Internally normalized to sum to 1. 
* `nlv` : Nb. latent variables (LVs) to consider for each block. 
    A vector having a length equal to the nb. blocks.
* `scal` : Boolean. If `true`, each column of blocks in `Xbl` and 
    of `Y` is scaled by its uncorrected standard deviation 
    (before the block scaling).

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
path_jdat = dirname(dirname(pathof(JchemoData)))
db = joinpath(path_jdat, "data/ham.jld2") 
@load db dat
pnames(dat) 

X = dat.X
y = dat.Y.c1
group = dat.group
listbl = [1:11, 12:19, 20:25]
Xbl = mblock(X, listbl)
# "New" = first two rows of Xbl 
Xbl_new = mblock(X[1:2, :], listbl)

nlv = [2; 1; 2]
fm = soplsr(Xbl, y; nlv = nlv) ;
pnames(fm)
fm.T
Jchemo.transform(fm, Xbl_new)
[y Jchemo.predict(fm, Xbl).pred]
Jchemo.predict(fm, Xbl_new).pred
```
"""
function soplsr(Xbl, Y, weights = ones(nro(Xbl[1])); nlv,
        scal = false)
    Y = ensure_mat(Y)
    n = size(Xbl[1], 1)
    q = nco(Y)   
    nbl = length(Xbl)
    weights = mweight(weights)
    D = Diagonal(weights)
    fm = list(nbl)
    pred = similar(Xbl[1], n, q)
    b = list(nbl)
    # First block
    fm[1] = plskern(Xbl[1], Y, weights; nlv = nlv[1], 
        scal = scal)
    T = fm[1].T
    pred .= Jchemo.predict(fm[1], Xbl[1]).pred
    b[1] = nothing
    # Other blocks
    if nbl > 1
        for i = 2:nbl
            b[i] = inv(T' * (D * T)) * T' * (D * Xbl[i])
            X = Xbl[i] - T * b[i]
            fm[i] = plskern(X, Y - pred, weights; nlv = nlv[i])
            T = hcat(T, fm[i].T)
            pred .+= Jchemo.predict(fm[i], X).pred 
        end
    end
    Soplsr(fm, T, pred, b)
end

""" 
    transform(object::Soplsr, Xbl)
Compute latent variables (LVs = scores T) from a fitted model.
* `object` : The fitted model.
* `Xbl` : A list (vector) of blocks (matrices) for which LVs are computed.
""" 
function transform(object::Soplsr, Xbl)
    nbl = length(object.fm)
    T = transform(object.fm[1], Xbl[1])
    if nbl > 1
        @inbounds for i = 2:nbl
            X = Xbl[i] - T * object.b[i]
            T = hcat(T, transform(object.fm[i], X))
        end
    end
    T
end

"""
    predict(object::Soplsr, Xbl)
Compute Y-predictions from a fitted model.
* `object` : The fitted model.
* `Xbl` : A list (vector) of X-data for which predictions are computed.
""" 
function predict(object::Soplsr, Xbl)
    nbl = length(object.fm)
    T = transform(object.fm[1], Xbl[1])
    pred =  object.fm[1].ymeans' .+ T * object.fm[1].C'
    if nbl > 1
        @inbounds for i = 2:nbl
            X = Xbl[i] - T * object.b[i]
            zT = transform(object.fm[i], X)
            pred .+= object.fm[i].ymeans' .+ zT * object.fm[i].C'
            T = hcat(T, transform(object.fm[i], X))
        end
    end
    (pred = pred,)
end



