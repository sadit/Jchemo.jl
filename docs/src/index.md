```@meta
DocTestSetup  = quote
    using Jchemo
end
```

# Jchemo.jl

Documentation for [Jchemo.jl](https://github.com/mlesnoff/Jchemo.jl).

## Overview

**Jchemo.jl** is a package for [**data exploration and prediction**](https://mlesnoff.github.io/Jchemo.jl/dev/domains/) with focus on **high dimensional data**. 

The package was initially designed about **partial least squares regression and discrimination models** and variants, in particular locally weighted PLS models (**LWPLS**) (e.g. https://doi.org/10.1002/cem.3209).
Then, it has been expanded to many other methods for 
analyzing high dimensional data. 

The package was named **Jchemo** since it is orientated to chemometrics, but most of the provided methods are fully **generic to other domains**. 

Functions such as **transform**, **predict**, **coef** and **summary** are available. 
**Tuning the predictive models** is facilitated by generic functions **gridscore** (validation dataset) and 
**gridcv** (cross-validation). Faster versions of these functions are also available for models based on latent variables (LVs) 
(**gridscorelv** and **gridcvlv**) and ridge regularization (**gridscorelb** and **gridcvlb**).

Most of the functions of the package have a **help page** (providing an example), e.g.:

```julia
?savgol
```

**Examples** demonstrating **Jchemo.jl** are available in project [**JchemoDemo**](https://github.com/mlesnoff/JchemoDemo), used for training only. **The datasets** of the examples are stored in package [**JchemoData.jl**](https://github.com/mlesnoff/JchemoData.jl).

Some of the functions of the package (in particular those using kNN selections) use **multi-threading** 
to speed the computations. Taking advantage of this requires to specify a relevant number 
of threads (e.g. from the 'Settings' menu of the VsCode Julia extension and the file 'settings.json').

**Jchemo.jl** uses **Makie.jl** for plotting. To install and load one of the Makie's backends (e.g. **CairoMakie.jl**) is required to display the plots. 

Before to update the package, it is recommended to have a look on 
[**What changed**](https://github.com/mlesnoff/Jchemo.jl/tree/master/docs/src/news.md) to avoid
problems due to eventual breaking changes. 


```@autodocs
Modules = [Jchemo]
Order   = [:function, :type]
```

