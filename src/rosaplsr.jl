struct Rosaplsr
    T::Matrix{Float64}
    P::Matrix{Float64}
    R::Matrix{Float64}
    W::Matrix{Float64}
    C::Matrix{Float64}
    TT::Vector{Float64}
    xmeans::Vector{Vector{Float64}}
    xscales::Vector{Vector{Float64}}
    ymeans::Vector{Float64}
    yscales::Vector{Float64}
    weights::Vector{Float64}
    bl::Vector
end

"""
    rosaplsr(Xbl, Y, weights = ones(nro(Xbl[1])); nlv)
    rosaplsr!(Xbl, Y, weights = ones(nro(Xbl[1])); nlv)
Multiblock PLSR with the ROSA algorithm (Liland et al. 2016).
* `Xbl` : List (vector) of blocks (matrices) of X-data. 
    Each component of the list is a block.
* `Y` : Y-data.
* `weights` : Weights of the observations (rows). 
    Internally normalized to sum to 1. 
* `nlv` : Nb. latent variables (LVs) to consider.
* `scal` : Boolean. If `true`, each column of blocks in `Xbl` and 
    of `Y` is scaled by its uncorrected standard deviation 
    (before the block scaling).

The function has the following differences with the original 
algorithm of Liland et al. (2016):
* Scores T are not normed to 1.
* Multivariate `Y` is allowed. In such a case, the squared residuals are summed 
    over the columns for finding the winning block for each global LV 
    (therefore Y-columns should have the same scale).

## References
Liland, K.H., Næs, T., Indahl, U.G., 2016. ROSA — a fast extension of partial least 
squares regression for multiblock data analysis. Journal of Chemometrics 30, 
651–662. https://doi.org/10.1002/cem.2824

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

nlv = 5
fm = rosaplsr(Xbl, y; nlv = nlv) ;
pnames(fm)
fm.T
Jchemo.transform(fm, Xbl_new)
[y Jchemo.predict(fm, Xbl).pred]
Jchemo.predict(fm, Xbl_new).pred
```
""" 
function rosaplsr(Xbl, Y, weights = ones(nro(Xbl[1])); nlv,
        scal = false)
    nbl = length(Xbl)  
    zXbl = list(nbl, Matrix{Float64})
    @inbounds for k = 1:nbl
        zXbl[k] = copy(ensure_mat(Xbl[k]))
    end
    rosaplsr!(zXbl, copy(ensure_mat(Y)), weights; nlv = nlv, 
        scal = scal)
end

function rosaplsr!(Xbl, Y, weights = ones(nro(Xbl[1])); nlv,
        scal = false)
    n = nro(Xbl[1])
    q = nco(Y)   
    nbl = length(Xbl)
    weights = mweight(weights)
    D = Diagonal(weights)
    xmeans = list(nbl, Vector{Float64})
    xscales = list(nbl, Vector{Float64})
    p = fill(0, nbl)
    Threads.@threads for k = 1:nbl
        p[k] = nco(Xbl[k])
        xmeans[k] = colmean(Xbl[k], weights) 
        xscales[k] = ones(nco(Xbl[k]))
        if scal 
            xscales[k] = colstd(Xbl[k], weights)
            Xbl[k] .= cscale(Xbl[k], xmeans[k], xscales[k])
        else
            Xbl[k] .= center(Xbl[k], xmeans[k])
        end
    end
    ymeans = colmean(Y, weights)
    yscales = ones(q)
    if scal 
        yscales .= colstd(Y, weights)
        cscale!(Y, ymeans, yscales)
    else
        center!(Y, ymeans)
    end
    # Pre-allocation
    W = similar(Xbl[1], sum(p), nlv)
    P = copy(W)
    T = similar(Xbl[1], n, nlv)
    TT = similar(Xbl[1], nlv)    
    C = similar(Xbl[1], q, nlv)
    DY = similar(Xbl[1], n, q)
    t   = similar(Xbl[1], n)
    dt  = similar(Xbl[1], n)   
    c   = similar(Xbl[1], q)
    zp_bl = list(nbl, Vector{Float64})
    zp = similar(Xbl[1], sum(p))
    #ssr = similar(Xbl[1], nbl)
    corr = similar(Xbl[1], nbl)
    Wbl = list(nbl, Array{Float64})
    wbl = list(nbl, Vector{Float64})  # List of the weights "w" by block for a given "a"
    zT = similar(Xbl[1], n, nbl)      # Matrix gathering the nbl scores for a given "a"
    bl = fill(0, nlv)
    #Res = zeros(n, q, nbl)
    ### Start 
    @inbounds for a = 1:nlv
        DY .= D * Y  # apply the metric on covariance
        @inbounds for k = 1:nbl
            XtY = Xbl[k]' * DY
            if q == 1
                wbl[k] = vec(XtY)
                #wbl[k] = vec(cor(Xbl[k], Y))
                wbl[k] ./= norm(wbl[k])
            else
                wbl[k] = svd!(XtY).U[:, 1]
            end
            zT[:, k] .= Xbl[k] * wbl[k]
        end
        # GS Orthogonalization of the scores
        if a > 1
            z = vcol(T, 1:(a - 1))
            zT .= zT .- z * inv(z' * (D * z)) * z' * (D * zT)
        end
        # Selection of the winner block
        ### Old
        #@inbounds for k = 1:nbl
        #    t = vcol(zT, k)
        #    dt .= weights .* t
        #    tt = dot(t, dt)
        #    Res[:, :, k] .= Y .- (t * t') * DY / tt
        #end
        #ssr = vec(sum(Res.^2, dims = (1, 2)))
        #opt = findmin(ssr)[2][1]
        ### End
        # Much faster:
        @inbounds for k = 1:nbl
            t = vcol(zT, k)
            corr[k] = sum(corm(Y, t, weights).^2)
        end
        opt = findmax(corr)[2][1]
        # End
        bl[a] = opt
        # Outputs for winner
        t .= zT[:, opt]
        dt .= weights .* t
        tt = dot(t, dt)
        mul!(c, Y', dt)
        c ./= tt     
        T[:, a] .= t
        TT[a] = tt
        C[:, a] .= c
        # Old
        #Y .= Res[:, :, opt]
        # End
        Y .-= (t * t') * DY / tt
        for k = 1:nbl
            zp_bl[k] = Xbl[k]' * dt
        end
        zp .= reduce(vcat, zp_bl)
        P[:, a] .= zp / tt
        # Orthogonalization of the weights "w" by block
        zw = wbl[opt]
        if (a > 1) && isassigned(Wbl, opt)       
            zW = Wbl[opt]
            zw .= zw .- zW * (zW' * zw)
        end
        zw ./= norm(zw)
        if !isassigned(Wbl, opt) 
            Wbl[opt] = reshape(zw, :, 1)
        else
            Wbl[opt] = hcat(Wbl[opt], zw)
        end
        # Build the weights over the overall matrix
        z = zeros(nbl) ; z[opt] = 1
        W[:, a] .= reduce(vcat, z .* wbl)
    end
    R = W * inv(P' * W)
    Rosaplsr(T, P, R, W, C, TT, xmeans, xscales, ymeans, yscales, weights, bl)
end

""" 
    transform(object::Rosaplsr, Xbl; nlv = nothing)
Compute latent variables (LVs = scores T) from a fitted model.
* `object` : The fitted model.
* `Xbl` : A list (vector) of blocks (matrices) of X-data for which LVs are computed.
* `nlv` : Nb. LVs to consider.
""" 
function transform(object::Rosaplsr, Xbl; nlv = nothing)
    a = size(object.T, 2)
    isnothing(nlv) ? nlv = a : nlv = min(nlv, a)
    nbl = length(object.xmeans)
    zXbl = list(nbl, Matrix{Float64})
    Threads.@threads for k = 1:nbl
        zXbl[k] = cscale(Xbl[k], object.xmeans[k], object.xscales[k])
    end
    reduce(hcat, zXbl) * vcol(object.R, 1:nlv)
end

"""
    coef(object::Rosaplsr; nlv = nothing)
Compute the X b-coefficients of a model fitted with `nlv` LVs.
* `object` : The fitted model.
* `nlv` : Nb. LVs to consider.
""" 
function coef(object::Rosaplsr; nlv = nothing)
    a = size(object.T, 2)
    isnothing(nlv) ? nlv = a : nlv = min(nlv, a)
    zxmeans = reduce(vcat, object.xmeans)
    beta = object.C[:, 1:nlv]'
    xscales = reduce(vcat, object.xscales)
    W = Diagonal(object.yscales)
    B = Diagonal(1 ./ xscales) * vcol(object.R, 1:nlv) * beta * W
    int = object.ymeans' .- zxmeans' * B
    (B = B, int = int)
end

"""
    predict(object::Rosaplsr, Xbl; nlv = nothing)
Compute Y-predictions from a fitted model.
* `object` : The fitted model.
* `Xbl` : A list (vector) of X-data for which predictions are computed.
* `nlv` : Nb. LVs, or collection of nb. LVs, to consider. 
""" 
function predict(object::Rosaplsr, Xbl; nlv = nothing)
    a = size(object.T, 2)
    isnothing(nlv) ? nlv = a : nlv = (max(minimum(nlv), 0):min(maximum(nlv), a))
    le_nlv = length(nlv)
    X = reduce(hcat, Xbl)
    pred = list(le_nlv, Matrix{Float64})
    @inbounds for i = 1:le_nlv
        z = coef(object; nlv = nlv[i])
        pred[i] = z.int .+ X * z.B
    end 
    le_nlv == 1 ? pred = pred[1] : nothing
    (pred = pred,)
end




