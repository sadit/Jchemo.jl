"""
    locw(Xtrain, Ytrain, X ; 
        listnn, listw = nothing, fun, verbose = false, kwargs...)
Compute predictions for a given kNN model.
* `Xtrain` : Training X-data.
* `Ytrain` : Training Y-data.
* `X` : X-data (m observations) to predict.
* `listnn` : List of m vectors of indexes.
* `listw` : List of m vectors of weights.
* `fun` : Function computing the model on the m neighborhoods.
* `verbose` : If true, fitting information are printed.
* `kwargs` : Keywords arguments to pass in function fun. 

Each component i of `listnn` and `listw` contains the indexes and weights, respectively,
of the nearest neighbors of x_i in Xtrain. The sizes of the neighborhood 
for i = 1,...,m can be different.

All the arguments in kwargs must have length = 1 (not collections).
"""
function locw(Xtrain, Ytrain, X; 
        listnn, listw = nothing, fun, verbose = false, kwargs...)
    m = nro(X)
    q = nco(Ytrain)
    pred = similar(Ytrain, m, q)
    #@inbounds for i = 1:m
    Threads.@threads for i = 1:m
        verbose ? print(i, " ") : nothing
        s = listnn[i]
        length(s) == 1 ? s = (s:s) : nothing
        zYtrain = Ytrain[s, :]
        ## For discrimination, 
        ## case where all the neighbors are of same class
        if q == 1 && length(unique(zYtrain)) == 1
            pred[i, :] .= zYtrain[1]
        ## End
        else
            if isnothing(listw)
                fm = fun(Xtrain[s, :],  zYtrain; kwargs...)
            else
                fm = fun(Xtrain[s, :], zYtrain, listw[i] ; kwargs...)
            end
            pred[i, :] = Jchemo.predict(fm, X[i:i, :]).pred
        end
    end
    verbose ? println() : nothing    
    (pred = pred,)
end





