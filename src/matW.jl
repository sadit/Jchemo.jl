"""
    matB(X, y; fun = mean)
Compute the between covariance matrix ("B") of `X`.
* `X` : X-data (n, p).
* `y` : A vector (n) defing the class memberships.

## Examples
```julia
n = 10 ; p = 3
X = rand(n, p)
X
y = rand(1:3, n)
#y = [3 ; ones(n - 2) ; 10]
res = matB(X, y)
res.B
res.lev
res.ni

res = matW(X, y)
res.W 
res.Wi

matW(X, y).W + matB(X, y).B 
cov(X; corrected = false)
```
""" 
matB = function(X, y)
    X = ensure_mat(X)
    res = aggstat(X, y; fun = mean)
    ni = tab(y).vals
    B = covm(res.X, mweight(ni))
    (B = B, ct = res.X, lev = res.lev, ni)
end


"""
    matW(X, y; fun = mean)
Compute the within covariance matrix ("W") of `X`.
* `X` : X-data (n, p).
* `y` : A vector (n) defing the class memberships.

If class "i" contains only one observation, 
W_i is computed as `cov(X; corrected = false)`.

For examples, see `?matB`. 
""" 
matW = function(X, y)
    X = ensure_mat(X)
    y = vec(y)  # required for findall 
    ztab = tab(y)
    lev = ztab.keys
    ni = ztab.vals
    nlev = length(lev)
    ## Case with y(s) with only 1 obs
    if sum(ni .== 1) > 0
        sigma_1obs = cov(X; corrected = false)
    end
    ## End
    w = mweight(ni)
    Wi = list(nlev, Matrix{Float64})
    W = zeros(1, 1)
    @inbounds for i in 1:nlev 
        if ni[i] == 1
            Wi[i] = sigma_1obs
        else
            s = findall(y .== lev[i])
            Wi[i] = cov(X[s, :]; corrected = false)
        end
        if i == 1  
            W = w[i] * Wi[i] 
        else 
            W = W + w[i] * Wi[i]
            # Alternative: Could give weight=0 to the class(es) with 1 obs
        end
    end
    (W = W, Wi, lev, ni)
end


