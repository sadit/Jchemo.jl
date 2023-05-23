"""
    difmean(X1, X2)
Compute a matrix of column means difference between two matrices.
* `X1` : Matrix of pectra (n1, p).
* `X2` : Matrix of pectra (n2, p).

The function returns a matrix D (1, p) containing the detrimental information
that has to be removed from spectra `X1` and `X2` by orthogonalization
(calibration transfer; see function `eposvd`). Matrix D is computed by the 
difference between the two mean spectra (column means of `X1` and `X2`).

## Examples
```julia
```
"""
function difmean(X1, X2)
    xmeans1 = colmean(X1)
    xmeans2 = colmean(X2)
    xmeans1 ./= norm(xmeans1)
    xmeans2 ./= norm(xmeans2)
    D = (xmeans1 - xmeans2)'
    (D = D, xmeans1, xmeans2)
end
