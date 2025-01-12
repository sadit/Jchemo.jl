struct Plslda    # for plslda and plsqda 
    fm  
    lev::AbstractVector
    ni::AbstractVector
end

"""
    plslda(X, y, weights = ones(nro(X)); nlv, 
        prior = "unif", scal = false)
LDA on PLS latent variables (PLS-LDA).
* `X` : X-data.
* `y` : y-data (class membership).
* `weights` : Weights of the observations. 
    Internally normalized to sum to 1. 
* `nlv` : Nb. latent variables (LVs) to compute.
* `prior` : Type of prior probabilities for class membership.
    Posible values are: "unif" (uniform), "prop" (proportional).
* `scal` : Boolean. If `true`, each column of `X` 
    is scaled by its uncorrected standard deviation.

The training variable `y` (univariate class membership) is transformed
to a dummy table (Ydummy) containing nlev columns, where nlev is the number 
of classes present in `y`. Each column of Ydummy is a dummy variable (0/1). 
Then, a PLS2 is implemented on `X` and Ydummy, 
returning `nlv` latent variables (LVs). Finally, a LDA is run on these LVs and `y`. 

## Examples
```julia
using JLD2
using JchemoData
path_jdat = dirname(dirname(pathof(JchemoData)))
db = joinpath(path_jdat, "data/forages.jld2") 
@load db dat
pnames(dat)

X = dat.X 
Y = dat.Y 
s = Bool.(Y.test)
Xtrain = rmrow(X, s)
ytrain = rmrow(Y.typ, s)
Xtest = X[s, :]
ytest = Y.typ[s]

tab(ytrain)
tab(ytest)

## nlv must be >=1 
## (conversely to plsrda for which nlv >= 0)
nlv = 20      
fm = plslda(Xtrain, ytrain; nlv = nlv) ;    
#fm = plsqda(Xtrain, ytrain; nlv = nlv) ;
pnames(fm)
pnames(fm.fm)

res = Jchemo.predict(fm, Xtest) ;
pnames(res)
res.pred
err(res.pred, ytest)
confusion(res.pred, ytest).cnt

Jchemo.transform(fm, Xtest)
Jchemo.transform(fm, Xtest; nlv = 2)

fm_pls = fm.fm.fm_pls ;
Jchemo.transform(fm_pls, Xtest)
summary(fm_pls, Xtrain)
Jchemo.coef(fm_pls).B
Jchemo.coef(fm_pls, nlv = 1).B
Jchemo.coef(fm_pls, nlv = 2).B

fm_da = fm.fm.fm_da ;
T = Jchemo.transform(fm_pls, Xtest)
Jchemo.predict(fm_da[nlv], T).pred

Jchemo.predict(fm, Xtest; nlv = 1:2).pred
```
""" 
function plslda(X, y, weights = ones(nro(X)); nlv, 
        prior = "unif", scal = false)
    res = dummy(y)
    ni = tab(y).vals
    fm_pls = plskern(X, res.Y, weights; nlv = nlv, scal = scal)
    fm_da = list(nlv)
    @inbounds for i = 1:nlv
        fm_da[i] = lda(fm_pls.T[:, 1:i], y; prior = prior)
    end
    fm = (fm_pls = fm_pls, fm_da = fm_da)
    Plslda(fm, res.lev, ni)
end

""" 
    transform(object::Plslda, X; nlv = nothing)
Compute latent variables (LVs = scores T) from a fitted model and a matrix X.
* `object` : The fitted model.
* `X` : Matrix (m, p) for which LVs are computed.
* `nlv` : Nb. LVs to consider.
""" 
function transform(object::Plslda, X; nlv = nothing)
    transform(object.fm.fm_pls, X; nlv = nlv)
end

"""
    predict(object::Plslda, X; nlv = nothing)
Compute Y-predictions from a fitted model.
* `object` : The fitted model.
* `X` : X-data for which predictions are computed.
* `nlv` : Nb. LVs, or collection of nb. LVs, to consider. 
   
""" 
function predict(object::Plslda, X; nlv = nothing)
    X = ensure_mat(X)
    m = size(X, 1)
    a = size(object.fm.fm_pls.T, 2)
    isnothing(nlv) ? nlv = a : nlv = (max(minimum(nlv), 0):min(maximum(nlv), a))
    le_nlv = length(nlv)
    pred = list(le_nlv, Union{Matrix{Int64}, Matrix{Float64}, Matrix{String}})
    posterior = list(le_nlv, Matrix{Float64})
    @inbounds for i = 1:le_nlv
        znlv = nlv[i]
        T = transform(object.fm.fm_pls, X, nlv = znlv)
        zres = predict(object.fm.fm_da[znlv], T)
        z =  mapslices(argmax, zres.posterior; dims = 2) 
        pred[i] = reshape(replacebylev2(z, object.lev), m, 1)
        posterior[i] = zres.posterior
    end 
    if le_nlv == 1
        pred = pred[1]
        posterior = posterior[1]
    end
    (pred = pred, posterior = posterior)
end





