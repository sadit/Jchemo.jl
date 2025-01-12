struct Occknndis
    d::DataFrame
    fm
    T::Array{Float64}
    tscales::Vector{Float64}
    k::Int
    e_cdf::ECDF
    cutoff::Real    
end

"""
    occknndis(X; nlv, nsamp, k, 
        typc = "mad", cri = 3, alpha = .025,
        scal = false, kwargs...)
One-class classification using global k-nearest neighbors distances.

* `X` : X-data (training).
* `nlv` : Nb. PCA components for the distances computations.
* `nsamp` : Nb. of observations (rows) sampled in the training `X`
    used to compute the H0 empirical distribution of outlierness.
* `k` : Nb. of neighbors used to compute the outlierness.
* `typc` : Type of cutoff ("mad" or "q"). See Thereafter.
* `cri` : When `typc = "mad"`, a constant. See thereafter.
* `alpha` : When `typc = "q"`, a risk-I level. See thereafter.
* `scal` : Boolean. If `true`, each column of `X` is scaled
    by its uncorrected standard deviation.
* `kwargs` : Optional arguments to pass in function `kde` of KernelDensity.jl
    (see function `kde1`).

Let us note q a given observation, and o[q] a neighbor of q 
within the training data `X`. The `k` nearest neighbors of q
define the neighborhood NNk(q) = {o.1[q], ...., o.k[q]} 
(if q belongs to the training `X`, q is removed from NNk(q)). 

The global outlierness of any observation q relatively to `X`, say dk(q),
is computed as the median distance to NNk(q):
* dk(q) = median{dist(q, o.j[q]), j = 1,...,k}.

Outlierness dk(q) is then compared to the outlierness distribution
estimated for the training data `X`, say distribution H0.   
If dk(q) is extreme compared to H0, observation q may come from a 
different distribution than the training data `X`.

H0 is estimated by Monte Carlo, as follows:
* A number of `nsamp` observations (rows) are sampled without replacement 
    within the training data `X`.
* For each of these `nsamp` training observations, say q.j {j = 1, ..., nsamp},
    outlierness dk(q.j) is computed. This returns a vector of `nsamp` 
    outlierness values {dk(q.j), j = 1,...,nsamp}. 
* This vector defines the empirical outlierness distribution of 
    observations assumed to come from the same distribution as 
    the training data `X` ("hypothesis H0"). 

Then, function `predict` computes outlierness dk(q) for each 
new observation q.       

In the function, distances are computed as Mahalanobis distances in a 
PCA score space (internally computed), cf. argument `nlv`.

See `?occsd` for details on outputs.

## Examples
```julia
using JchemoData, JLD2, CairoMakie
path_jdat = dirname(dirname(pathof(JchemoData)))
db = joinpath(path_jdat, "data/challenge2018.jld2") 
@load db dat
pnames(dat)
X = dat.X    
Y = dat.Y
f = 21 ; pol = 3 ; d = 2 ;
Xp = savgol(snv(X); f = f, pol = pol, d = d) 
s = Bool.(Y.test)
Xtrain = rmrow(Xp, s)
Ytrain = rmrow(Y, s)
Xtest = Xp[s, :]
Ytest = Y[s, :]

g1 = "EHH" ; g2 = "PEE"
#g1 = "EHH" ; g2 = "EHH"
s1 = Ytrain.typ .== g1
s2 = Ytest.typ .== g2
zXtrain = Xtrain[s1, :]    
zXtest = Xtest[s2, :] 
ntrain = nro(zXtrain)
ntest = nro(zXtest)
ntot = ntrain + ntest
(ntot = ntot, ntrain, ntest)

fm = pcasvd(zXtrain, nlv = 5) ; 
Ttrain = fm.T
Ttest = Jchemo.transform(fm, zXtest)
T = vcat(Ttrain, Ttest)
group = vcat(repeat(["0-Train"], ntrain), repeat(["1-Test"], ntest))
i = 1
plotxy(T[:, i:(i + 1)], group;
    xlabel = string("PC", i), ylabel = string("PC", i + 1)).f

#### End data

nlv = 30
nsamp = 300
k = round(.7 * ntrain)
fm = occknndis(zXtrain; nlv = nlv, 
    nsamp = nsamp, k = k) ;
fm.d
hist(fm.d.dstand; bins = 50)

res = Jchemo.predict(fm, zXtest) ;
res.d
res.pred
tab(res.pred)

d1 = fm.d.dstand
d2 = res.d.dstand
d = vcat(d1, d2)
group = [repeat(["0-Train"], length(d1)); repeat(["1-Test"], length(d2))]
f, ax = plotxy(1:length(d), d, group; 
    resolution = (600, 400), xlabel = "Obs. index", 
    ylabel = "Standardized distance")
hlines!(ax, 1)
f
```
""" 
function occknndis(X; nlv, nsamp, k, 
        typc = "mad", cri = 3, alpha = .025,
        scal = false, kwargs...)
    X = ensure_mat(X)
    n = nro(X)
    k = Int64(k)
    fm = pcasvd(X; nlv = nlv, scal = scal)
    # For the Mahalanobis distance
    tscales = colstd(fm.T)
    scale!(fm.T, tscales)
    # End
    samp = sample(1:n, nsamp; replace = false)
    res = getknn(fm.T, fm.T[samp, :]; 
            k = k + 1, metric = "eucl")
    d = zeros(nsamp)
    @inbounds for i = 1:nsamp
        d[i] = median(res.d[i][2:end])
    end
    typc == "mad" ? cutoff = median(d) + cri * mad(d) : nothing
    typc == "q" ? cutoff = quantile(d, 1 - alpha) : nothing
    e_cdf = StatsBase.ecdf(d)
    p_val = pval(e_cdf, d)
    d = DataFrame(d = d, dstand = d / cutoff, pval = p_val)
    Occknndis(d, fm, fm.T, tscales, k, e_cdf, cutoff)
end

"""
    predict(object::Occknndis, X)
Compute predictions from a fitted model.
* `object` : The fitted model.
* `X` : X-data for which predictions are computed.
""" 
function predict(object::Occknndis, X)
    X = ensure_mat(X)
    m = size(X, 1)
    T = transform(object.fm, X)
    scale!(T, object.tscales)
    res = getknn(object.T, T; k = object.k, metric = "eucl") 
    d = zeros(m)
    @inbounds for i = 1:m
        d[i] = median(res.d[i])
    end
    p_val = pval(object.e_cdf, d)
    d = DataFrame(d = d, dstand = d / object.cutoff, pval = p_val)
    pred = reshape(Int64.(d.dstand .> 1), m, 1)
    (pred = pred, d)
end




