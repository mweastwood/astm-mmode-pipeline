# Extract a postage stamp image from the map.

function postage_stamp(map, direction)
    xgrid = linspace(-deg2rad(5.0), +deg2rad(5.0), 201)
    ygrid = linspace(-deg2rad(5.0), +deg2rad(5.0), 201)
    postage_stamp(map, xgrid, ygrid, direction)
end

function postage_stamp(map, xgrid, ygrid, ra, dec)
    direction = Direction(dir"ITRF", ra*radians, dec*radians)
    postage_stamp(map, xgrid, ygrid, direction)
end

function postage_stamp(map, xgrid, ygrid, direction)
    up = [direction.x, direction.y, direction.z]
    north = [0, 0, 1] - up*direction.z
    north /= norm(north)
    east = cross(north, up)
    θlist = Float64[]
    ϕlist = Float64[]
    for y in ygrid, x in xgrid
        vector = up + x*east + y*north
        vector /= norm(vector)
        θ = acos(vector[3])
        ϕ = atan2(vector[2], vector[1])
        push!(θlist, θ)
        push!(ϕlist, ϕ)
    end
    image = LibHealpix.interpolate(map, θlist, ϕlist)
    reshape(image, length(xgrid), length(ygrid))
end

