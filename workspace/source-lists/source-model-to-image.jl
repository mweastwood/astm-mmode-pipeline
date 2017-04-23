module Driver

using TTCal
using PyPlot
using CasaCore.Measures
using FileIO

function dir2vector(direction)
    [direction.x; direction.y; direction.z]
end

function dir2unitvectors(direction)
    up = [direction.x; direction.y; direction.z]
    up /= norm(up)
    north = [0; 0; 1]
    north -= dot(up, north)*up
    north /= norm(north)
    east = cross(north, up)
    up, north, east
end

function go()
    sources = readsources("getdata-sources.json")
    for source in sources
        if source.name == "Cyg A"
            plot_image(source, source.components[1].direction)
            savefig("model-cyg-a.png", bbox_inches="tight", pad_inches=0)
        elseif source.name == "Cas A"
            direction = Direction(dir"J2000", "23h23m24s", "58d49m54s")
            plot_image(source, direction)
            savefig("model-cas-a.png", bbox_inches="tight", pad_inches=0)
        else
            continue
        end
        print("Continue? ")
        inp = chomp(readline())
        inp == "q" && break
    end
end

function plot_image(source, center)
    xgrid = linspace(-deg2rad(10/60), +deg2rad(10/60), 501)
    ygrid = linspace(-deg2rad(10/60), +deg2rad(10/60), 501)
    image = zeros(length(xgrid), length(ygrid))
    up, north, east = dir2unitvectors(center)

    for component in source.components
        vec = dir2vector(component.direction)
        flux = component.spectrum.stokes.I
        major_σ = component.major_fwhm / (2sqrt(2log(2)))
        minor_σ = component.minor_fwhm / (2sqrt(2log(2)))
        θ = component.position_angle

        x0 = dot(vec, east)
        y0 = dot(vec, north)
        major_axis =  cos(θ)*north + sin(θ)*east
        minor_axis = -sin(θ)*north + cos(θ)*east

        for jdx = 1:length(ygrid), idx = 1:length(xgrid)
            myvec = (xgrid[idx]-x0)*east + (ygrid[jdx]-y0)*north
            major_distance = dot(myvec, major_axis)
            minor_distance = dot(myvec, minor_axis)
            image[idx, jdx] += flux*exp(-0.5*major_distance^2/major_σ^2
                                        -0.5*minor_distance^2/minor_σ^2)
        end
    end
    figure(1); clf()
    imshow(flipdim(image.', 2), cmap=get_cmap("afmhot"), interpolation="nearest",
           extent=(-10, 10, -10, 10))
    ϕ = linspace(0, 2π, 501)
    plot(5cos(ϕ), 5sin(ϕ), "w--", lw=2)
    axis("off")
    grid("off")
    gca()[:get_xaxis]()[:set_visible](false)
    gca()[:get_yaxis]()[:set_visible](false)
    gca()[:set_aspect]("equal")
    colorbar()
end

end

