struct Plsravg
    fm
end

""" 
    plsravg(X, Y, weights = ones(nro(X)); nlv, 
        typf = "unif", typw = "bisquare",
        alpha = 0, K = 5, rep = 10, scal = false)
    plsravg!(X::Matrix, Y::Matrix, weights = ones(nro(X)); nlv, 
        typf = "unif", typw = "bisquare", 
        alpha = 0, K = 5, rep = 10, scal = false)
Averaging and stacking PLSR models with different numbers of 
    latent variables (LVs).
* `X` : X-data (n, p).
* `Y` : Y-data (n, q). Must be univariate (q = 1) if `typw` != "unif".
* `weights` : Weights (n) of the observations. Internally normalized to sum to 1.
* `nlv` : A character string such as "5:20" defining the range of the numbers of LVs 
    to consider ("5:20": the predictions of models with nb LVS = 5, 6, ..., 20 
    are averaged). Syntax such as "10" is also allowed ("10": correponds to
    the single model with 10 LVs).
* `typf` : Type of averaging. 
* `scal` : Boolean. If `true`, each column of `X` and `Y` 
    is scaled by its uncorrected standard deviation.

For `typf` in {"aic", "bic", "cv"}
* `typw` : Type of weight function. 
* `alpha` : Parameter of the weight function.

For `typf` = "stack"
* `K` : Nb. of folds segmenting the data in the (K-fold) CV.
* `rep` : Nb. of repetitions of the K-fold CV. 

Ensemblist method where the predictions are computed by averaging 
or stacking the predictions of a set of models built with different numbers of 
LVs.

For instance, if argument `nlv` is set to `nlv = "5:10"`, the prediction for 
a new observation is the average (eventually weighted) or stacking of the predictions 
returned by the models with 5 LVS, 6 LVs, ... 10 LVs, respectively.

Possible values of `typf` are: 
* "unif" : Simple average.
* "aic" : Weighted average based on AIC computed for each model.
* "bic" : Weighted average based on BIC computed for each model.
* "cv" : Weighted average based on RMSEP_CV computed for each model.
* "shenk" : Weighted average using "Shenk et al." weights computed for each model.
* "stack" : Linear stacking. A K-fold CV (eventually repeated) is done and 
the CV predictions are regressed (multiple linear model without intercept)
on the observed response data.

For arguments `typw` and `alpha` (weight function): see `?fweight`.

## References
Lesnoff, M., Roger, J.-M., Rutledge, D.N., 2021. Monte Carlo methods for estimating 
Mallows’s Cp and AIC criteria for PLSR models. Illustration on agronomic spectroscopic NIR data. 
Journal of Chemometrics n/a, e3369. https://doi.org/10.1002/cem.3369

Lesnoff, M., Andueza, D., Barotin, C., Barre, P., Bonnal, L., Fernández Pierna, J.A., Picard, 
F., Vermeulen, P., Roger, J.-M., 2022. Averaging and Stacking Partial Least Squares Regression Models 
to Predict the Chemical Compositions and the Nutritive Values of Forages from Spectral Near 
Infrared Data. Applied Sciences 12, 7850. https://doi.org/10.3390/app12157850

Shenk, J., Westerhaus, M., Berzaghi, P., 1997. Investigation of a LOCAL calibration 
procedure for near infrared instruments. 
Journal of Near Infrared Spectroscopy 5, 223. https://doi.org/10.1255/jnirs.115

Shenk et al. 1998 United States Patent (19). Patent Number: 5,798.526.

Zhang, M.H., Xu, Q.S., Massart, D.L., 2004. Averaged and weighted average partial 
least squares. Analytica Chimica Acta 504, 279–289. https://doi.org/10.1016/j.aca.2003.10.056

## Examples
```julia
using JchemoData, JLD2, CairoMakie
path_jdat = dirname(dirname(pathof(JchemoData)))
db = joinpath(path_jdat, "data/forages2.jld2") 
@load db dat
pnames(dat)
  
X = dat.X 
Y = dat.Y
summ(Y)
y = Y.ndf
#y = Y.dm

s = Bool.(Y.test)
Xtrain = rmrow(X, s)
ytrain = rmrow(y, s)
Xtest = X[s, :]
ytest = y[s]
ntrain = nro(Xtrain)
ntest = nro(Xtest)
(ntot = ntot, ntrain, ntest)

nlv = "0:50"
fm = plsravg(Xtrain, ytrain; nlv = nlv) ;
res = Jchemo.predict(fm, Xtest)
res.pred
rmsep(res.pred, ytest)
plotxy(vec(res.pred), ytest; color = (:red, .5),
    bisect = true, xlabel = "Prediction", ylabel = "Observed").f   

fm = plsravg(Xtrain, ytrain; nlv = nlv,
    typf = "cv") ;
res = Jchemo.predict(fm, Xtest)
res.pred
rmsep(res.pred, ytest)
```
""" 
function plsravg(X, Y, weights = ones(nro(X)); nlv, 
        typf = "unif", typw = "bisquare", 
        alpha = 0, K = 5, rep = 10, scal = false)
    plsravg!(copy(ensure_mat(X)), copy(ensure_mat(Y)), weights; nlv = nlv, 
        typf = typf, typw = typw, 
        alpha = alpha, K = K, rep = rep, scal = scal)
end

function plsravg!(X::Matrix, Y::Matrix, weights = ones(nro(X)); nlv, 
        typf = "unif", typw = "bisquare", 
        alpha = 0, K = 5, rep = 10, scal = false)
    if typf == "unif"
        fm = plsravg_unif!(X, Y, weights; nlv = nlv,
            scal = scal)
    elseif typf == "aic"
        fm = plsravg_aic!(X, Y, weights; nlv = nlv,
            bic = false, typw = typw, alpha = alpha,
            scal = scal)
    elseif typf == "bic"
        fm = plsravg_aic!(X, Y, weights; nlv = nlv,
            bic = true, typw = typw, alpha = alpha,
            scal = scal)
    elseif typf == "cv"
        fm = plsravg_cv!(X, Y, weights; nlv = nlv,
            typw = typw, alpha = alpha, 
            scal = scal)
    elseif typf == "shenk"
        fm = plsravg_shenk!(X, Y, weights; nlv = nlv,
            scal = scal)
    elseif typf == "stack"
        fm = plsrstack!(X, Y, weights; nlv = nlv, 
            K = K, rep = rep, 
            scal = scal) 
    end
    Plsravg(fm)
end

"""
    predict(object::Plsravg, X)
Compute Y-predictions from a fitted model.
* `object` : The fitted model.
* `X` : X-data for which predictions are computed.
""" 
function predict(object::Plsravg, X)
    res = predict(object.fm, X)
    (pred = res.pred, predlv = res.predlv)
end


