"""
    plotxy(x::AbstractVector, y::AbstractVector; resolution = (600, 400), 
        color = nothing, ellipse::Bool = false, prob = .95, 
        circle::Bool = false, bisect::Bool = false, zeros::Bool = false,
        xlabel = "", ylabel = "", title = "",
        kwargs...)
    plotxy(x::AbstractVector, y::AbstractVector, group::AbstractVector; resolution = (600, 400), 
        color = nothing, ellipse::Bool = false, prob = .95, 
        circle::Bool = false, bisect::Bool = false, zeros::Bool = false,
        xlabel = "", ylabel = "", title = "", leg::Bool = true,
        kwargs...)
    plotxy(X::Union{Matrix, DataFrame}; resolution = (600, 400), 
        color = nothing, ellipse::Bool = false, prob = .95, 
        circle::Bool = false, bisect::Bool = false, zeros::Bool = false,
        xlabel = "", ylabel = "", title = "", 
        kwargs...)
    plotxy(X::Union{Matrix, DataFrame}, group::AbstractVector; resolution = (600, 400), 
        color = nothing, ellipse::Bool = false, prob = .95, 
        circle::Bool = false, bisect::Bool = false, zeros::Bool = false,
        xlabel = "", ylabel = "", title = "", leg::Bool = true, 
        kwargs...)
        
Scatter plot of (x, y) data
* `x` : A x-vector (n).
* `y` : A y-vector (n). 
* `X` : A matrix (n, 2) (col1 = x, col2 = y). 
* `group` : Categorical variable defining groups. 
* `resolution` : Resolution (horizontal, vertical) of the figure.
* `color` : Set color(s). If `group` if used, `color` must be a vector of 
    same length as the number of levels in `group`.
* `ellipse` : Boolean. Draw an ellipse of confidence, assuming a Ch-square distribution
    with df = 2. If `group` is used, one ellipse is drawn per group.
* `prob` : Probability for the ellipse of confidence (default = .95).
*  `bisect` : Boolean. Draw a bisector.
*  `zeros` : Boolean. Draw horizontal and vertical axes passing through origin (0, 0).
*  `xlabel` : Label for the x-axis.
*  `ylabel` : Label for the y-axis.
*  `title` : Title of the graphic.
* `leg` : Boolean. If `group` is used, display a legend or not.
* `kwargs` : Optional arguments to pass in function `scatter` of Makie.

The user has to specify a backend (e.g. CairoMakie).

## Examples
```julia
using JchemoData, JLD2, CairoMakie
path_jdat = dirname(dirname(pathof(JchemoData)))
db = joinpath(path_jdat, "data/cassav.jld2") 
@load db dat
pnames(dat)

X = dat.X 
y = dat.Y.tbc
year = dat.Y.year
tab(year)
lev = mlev(year)
nlev = length(lev)

fm = pcasvd(X, nlv = 3) ; 
T = fm.T

plotxy(T[:, 1], T[:, 2]; color = (:red, .5)).f

plotxy(T[:, 1:2]; color = (:red, .5)).f

plotxy(T[:, 1], T[:, 2], year; ellipse = true).f

plotxy(T[:, 1:2], year; color = (:red, .5)).f

i = 1
colm = cgrad(:Dark2_5, nlev; categorical = true)
plotxy(T[:, i:(i + 1)], year; 
    color = colm,
    xlabel = string("PC", i), ylabel = string("PC", i + 1),
    zeros = true, ellipse = true).f

plotxy(T[:, 1:2], year).lev

## Adding several layers is possible
## (same syntax as in Makie)
A = rand(50, 2)
f, ax = plotxy(A; xlabel = "x1", ylabel = "x2")
ylims!(ax, -1, 2)
hlines!(ax, 0.5; color = :red, linestyle = :dot)
f

```
""" 
function plotxy(x::AbstractVector, y::AbstractVector; resolution = (600, 400), 
        color = nothing, ellipse::Bool = false, prob = .95, 
        circle::Bool = false, bisect::Bool = false, zeros::Bool = false,
        xlabel = "", ylabel = "", title = "", 
        kwargs...)
    f = Figure(resolution = resolution)
    ax = Axis(f; xlabel = xlabel, ylabel = ylabel, 
        title = title)
    if isnothing(color)
        scatter!(ax, x, y; kwargs...)
    else
        scatter!(ax, x, y; color = color, kwargs...)
    end
    if ellipse
        X = hcat(x, y)
        xmeans = colmean(X)
        radius = sqrt(quantile(Chi(2), prob))
        res = Jchemo.ellipse(cov(X); center = xmeans, radius = radius)
        if isnothing(color)
            lines!(ax, res.X; color = :grey40)
        else
            lines!(ax, res.X; color = color)
        end 
    end
    if circle
        z = Jchemo.ellipse(diagm(ones(2))).X
        lines!(ax, z; color = :grey60)
    end
    if bisect
        ablines!(ax, 0, 1)
    end
    if zeros
        hlines!(0; color = :grey60)
        vlines!(0; color = :grey60)
    end
    f[1, 1] = ax
    (f = f, ax = ax)
end

function plotxy(x::AbstractVector, y::AbstractVector, group::AbstractVector; resolution = (600, 400), 
        color = nothing, ellipse::Bool = false, prob = .95, 
        circle::Bool = false, bisect::Bool = false, zeros::Bool = false,
        xlabel = "", ylabel = "", title = "", leg::Bool = true,
        kwargs...)
    lev = mlev(group)
    nlev = length(lev)
    lab = string.(lev)
    f = Figure(resolution = resolution)
    ax = Axis(f; xlabel = xlabel, ylabel = ylabel, 
        title = title)
    for i = 1:nlev
        s = group .== lev[i]
        zx = x[s]
        zy = y[s]
        if isnothing(color)
            scatter!(ax, zx, zy; label = lab[i], kwargs...)
        else
            scatter!(ax, zx, zy; label = lab[i], color = color[i], 
                kwargs...)
        end
        if ellipse
            X = hcat(zx, zy)
            xmeans = colmean(X)
            radius = sqrt(quantile(Chi(2), prob))
            res = Jchemo.ellipse(cov(X); center = xmeans, radius = radius)
            if isnothing(color)
                lines!(ax, res.X; color = :grey40)
            else
                lines!(ax, res.X; color = color[i])
            end 
        end
    end
    if circle
        res = Jchemo.ellipse(diagm(ones(2))).X
        lines!(ax, res; color = :grey60)
    end
    if bisect
        ablines!(ax, 0, 1)
    end
    if zeros
        hlines!(0; color = :grey60)
        vlines!(0; color = :grey60)
    end
    f[1, 1] = ax
    if leg
        f[1, 2] = Legend(f, ax, "Group", framevisible = false)
    end
    (f = f, ax = ax, lev = lev)
end

function plotxy(X::Union{Matrix, DataFrame}; resolution = (600, 400), 
        color = nothing, ellipse::Bool = false, prob = .95, 
        circle::Bool = false, bisect::Bool = false, zeros::Bool = false,
        xlabel = "", ylabel = "", title = "", 
        kwargs...)
    plotxy(X[:, 1], X[:, 2]; resolution = resolution, 
        color = color, ellipse = ellipse, prob = prob, 
        circle = circle, bisect = bisect, zeros = zeros,
        xlabel = xlabel, ylabel = ylabel, title = title, 
        kwargs...)
end

function plotxy(X::Union{Matrix, DataFrame}, group::AbstractVector; resolution = (600, 400), 
        color = nothing, ellipse::Bool = false, prob = .95, 
        circle::Bool = false, bisect::Bool = false, zeros::Bool = false,
        xlabel = "", ylabel = "", title = "", leg::Bool = true,
        kwargs...)
    plotxy(X[:, 1], X[:, 2], group; resolution = resolution, 
        color = color, ellipse = ellipse, prob = prob, 
        circle = circle, bisect = bisect, zeros = zeros,
        xlabel = xlabel, ylabel = ylabel, title = title, leg = leg,
        kwargs...)
end
