struct LwplsrAgg
    X::Array{Float64}
    Y::Array{Float64}
    nlvdis::Int
    metric::String
    h::Real
    k::Int
    nlv::String
    verbose::Bool
end

"""
    lwplsr_agg(X, Y; nlvdis, metric, h, k, nlv, verbose = false)
Aggregation of KNN-LWPLSR models with different numbers of LVs.
* `X` : matrix (n, p), or vector (n,).
* `Y` : matrix (n, q), or vector (n,).
* `nlvdis` : The number of LVs to consider in the global PLS used for the dimension reduction before 
    calculating the dissimilarities. If `nlvdis = 0`, there is no dimension reduction.
* `metric` : The type of dissimilarity used for defining the neighbors. Possible values are "eucl" (default; Euclidean distance) 
    and "mahal" (Mahalanobis distance).
* `h` : A scale scalar defining the shape of the weight function. Lower is h, sharper is the function. See `wdist`.
* `k` : The number of nearest neighbors to select for each observation to predict.
* `nlv` : A character string such as "5:20" defining the range of the numbers of LVs 
    to consider ("5:20": the predictions of models with nb LVS = 5, 6, ..., 20 are averaged). 
    Syntax such as "10" is also allowed ("10": correponds to the single model with 10 LVs).
* `verbose` : If true, fitting information are printed.

Ensemblist method where the predictions are calculated by averaging the predictions 
of KNN-LWPLSR models (`lwplsr`) built with different numbers of latent variables (LVs).

For instance, if argument `nlv` is set to `nlv = "5:10"`, the prediction for a new observation 
is the simple average of the predictions returned by the models with 5 LVS, 6 LVs, ... 10 LVs, respectively.

""" 
function lwplsr_agg(X, Y; nlvdis, metric, h, k, nlv, verbose = false)
    return LwplsrAgg(X, Y, nlvdis, metric, h, k, nlv, verbose)
end

function predict(object::LwplsrAgg, X) 
    # Getknn
    if(object.nlvdis == 0)
        res = getknn(object.X, X; k = object.k, metric = object.metric)
    else
        fm = plskern(object.X, object.Y; nlv = object.nlvdis)
        res = getknn(fm.T, transform(fm, X); k = object.k, metric = object.metric)
    end
    listw = map(d -> wdist(d, object.h), res.d)
    # End
    pred = locw(object.X, object.Y, X; 
        listnn = res.ind, listw = listw, fun = plsr_agg, nlv = object.nlv, verbose = object.verbose).pred
    (pred = pred, listnn = res.ind, listd = res.d, listw = listw)
end



