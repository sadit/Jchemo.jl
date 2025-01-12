""" 
    plsldaavg(X, y, weights = ones(nro(X)); nlv,
        scal = false)
Averaging of PLS-LDA models with different numbers of 
    latent variables (LVs).
* `X` : X-data.
* `y` : y-data (class membership).
* weights : Weights of the observations.
    Internally normalized to sum to 1. 
* `nlv` : A character string such as "5:20" defining the range of the numbers of LVs 
    to consider ("5:20": the predictions of models with nb LVS = 5, 6, ..., 20 
    are averaged). Syntax such as "10" is also allowed ("10": correponds to
    the single model with 10 LVs).
* `scal` : Boolean. If `true`, each column of `X` 
    is scaled by its uncorrected standard deviation.

Ensemblist method where the predictions are calculated by "averaging" 
the predictions of a set of models built with different numbers of 
LVs.

For instance, if argument `nlv` is set to `nlv = "5:10"`, the prediction for 
a new observation is the most occurent class within the predictions 
returned by the models with 5 LVS, 6 LVs, ... 10 LVs, respectively.

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

## minimum of nlv must be >=1 
## (conversely to plsrdaavg)
fm = plsldaavg(Xtrain, ytrain; nlv = "1:40") ;    
#fm = plsldaavg(Xtrain, ytrain; nlv = "1:20") ;
pnames(fm)

res = Jchemo.predict(fm, Xtest) ;
pnames(res)
res.pred
err(res.pred, ytest)
confusion(res.pred, ytest).cnt
```
""" 
function plsldaavg(X, y, weights = ones(nro(X)); nlv,
        scal = false)
    n = size(X, 1)
    p = size(X, 2)
    nlv = eval(Meta.parse(nlv))
    nlvmax = maximum(nlv)
    nlv = (max(minimum(nlv), 0):min(nlvmax, n, p))
    w = ones(nlvmax + 1)
    # Uniform weights for the models
    w_mod = mweight(w[collect(nlv) .+ 1])
    # End
    fm = plslda(X, y, weights; nlv = nlvmax,
        scal = scal)
    Plsdaavg(fm, nlv, w_mod, fm.lev, fm.ni)
end




