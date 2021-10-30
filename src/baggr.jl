struct Baggr
    fm
    s_row  # in-bag
    s_col
    s_oob  # out-of-bag
end

""" 
    baggr(X, Y, weights = nothing; fun, rep = 50, 
        withr = false, rowsamp = 1, colsamp = 1, kwargs...)
Bagging of regression models.
* `X` : X-data (n obs., p variables).
* `Y` : Y-data (n obs., q variables).
* `weights` : Weights of the observations.
* `fun` : Name of the function computing the model to bagg.
* `rep` : Nb. of bagging repetitions.
* `withr`: Type of sampling of the observations
    (`true` => with replacement).
* `rowsamp` : Proportion of rows sampled in `X` 
    at each repetition.
* `colsamp` : Proportion of columns sampled (without replacement) in `X` 
    at each repetition.
* `kwargs` : Optional named arguments to pass in 'fun`.

## References

Breiman, L., 1996. Bagging predictors. Mach Learn 24, 123–140. 
https://doi.org/10.1007/BF00058655

Breiman, L., 2001. Random Forests. Machine Learning 45, 5–32. 
https://doi.org/10.1023/A:1010933404324

Genuer, R., 2010. Forêts aléatoires : aspects théoriques, 
sélection de variables et applications. PhD Thesis. Université Paris Sud - Paris XI.

Gey, S., 2002. Bornes de risque, détection de ruptures, boosting : 
trois thèmes statistiques autour de CART en régression (These de doctorat). 
Paris 11. http://www.theses.fr/2002PA112245
""" 
function baggr(X, Y, weights = nothing; fun, rep = 50, 
        withr = false, rowsamp = 1, colsamp = 1, kwargs...)
    X = ensure_mat(X)
    Y = ensure_mat(Y)
    n, p = size(X)
    q = size(Y, 2)   
    fm = list(rep)
    nrow = Int64(round(rowsamp * n))
    ncol = max(Int64(round(colsamp * p)), 1)
    s_row = fill(1, (nrow, rep))        # (nrow, rep)
    s_col = similar(s_row, ncol, rep)   # (ncol, rep) 
    s_oob = list(rep)
    srow = similar(s_row, nrow)    
    scol = similar(s_row, ncol)
    w = similar(X, nrow)
    zncol = collect(1:ncol) 
    zX = similar(X, nrow, ncol)
    zY = similar(Y, nrow, q)
    #Threads.@threads for i = 1:rep
    #@sync @distributed for i = 1:rep
    #@distributed for i = 1:rep
    @inbounds for i = 1:rep
        srow .= sample(1:n, nrow; replace = withr)
        s_oob[i] = findall(in(srow).(1:n) .== 0)
        if colsamp == 1
            scol .= zncol
        else
            scol .= sample(1:p, ncol; replace = false) 
        end
        zX .= X[srow, scol]
        zY .= Y[srow, :]
        if(isnothing(weights))
            fm[i] = fun(zX, zY; kwargs...)
        else
            w .= mweights(weights[srow])
            fm[i] = fun(zX, zY, w; kwargs...)
        end
        s_row[:, i] .= srow    
        s_col[:, i] .= scol
    end
    Baggr(fm, s_row, s_col, s_oob)
end

function predict(object::Baggr, X)
    rep = length(object.fm)
    scol = vcol(object.s_col, 1)
    # @view is not accepted by XGBoost.predict
    # @view(X[:, scol])
    acc = predict(object.fm[1], X[:, scol]).pred
    @inbounds for i = 2:rep
        scol = vcol(object.s_col, i)
        acc .+= predict(object.fm[i], X[:, scol]).pred
    end
    pred = acc ./ rep
    (pred = pred,)
end




