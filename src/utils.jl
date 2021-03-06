using Colors
using GraphPlot
using Makie
using Printf

function center_point(points)
    mean = [0.0, 0.0, 0.0]
    for point in points
        mean[1] += point[:x]
        mean[2] += point[:y]
        mean[3] += point[:z]
    end
    mean[1] /= size(points, 1)
    mean[2] /= size(points, 1)
    mean[3] /= size(points, 1)
    return mean
end

function get_hanging_node_between(g, v1, v2)
    if has_edge(g, v1, v2)
        return nothing
    end
    nodes1 = filter(v -> get_prop(g, v, :type) == "hanging", neighbors(g, v1))
    nodes2 = filter(v -> get_prop(g, v, :type) == "hanging", neighbors(g, v2))
    nodes = intersect(nodes1, nodes2)

    if size(nodes, 1) < 1
        return nothing
    end

    return nodes[1]
end

function add_meta_vertex!(g, x, y, z)
    add_vertex!(g)
    set_prop!(g, nv(g), :type, "vertex")
    set_prop!(g, nv(g), :x, convert(Float64, x))
    set_prop!(g, nv(g), :y, convert(Float64, y))
    set_prop!(g, nv(g), :z, convert(Float64, z))
    return nv(g)
end

function add_hanging!(g, x, y, z)
    add_vertex!(g)
    set_prop!(g, nv(g), :type, "hanging")
    set_prop!(g, nv(g), :x, x)
    set_prop!(g, nv(g), :y, y)
    set_prop!(g, nv(g), :z, z)
    return nv(g)
end

function add_interior!(g, v1, v2, v3, refine)
    add_vertex!(g)
    set_prop!(g, nv(g), :type, "interior")
    set_prop!(g, nv(g), :refine, refine)
    set_prop!(g, nv(g), :v1, v1)
    set_prop!(g, nv(g), :v2, v2)
    set_prop!(g, nv(g), :v3, v3)
    return nv(g)
end

interior_vertices(g, i) = [get_prop(g, i, :v1), get_prop(g, i, :v2), get_prop(g, i, :v3)]

function add_meta_edge!(g, v1, v2, boundary)
    add_edge!(g, v1, v2)
    set_prop!(g, v1, v2, :boundary, boundary)
end

distance(graph::AbstractMetaGraph, vertex_1::Integer, vertex_2::Integer) = cartesian_distance(props(graph, vertex_1), props(graph, vertex_2))

function cartesian_distance(p1, p2)
    # println("(x1-x2)^2: ", (convert(Float64, p1[:x])-convert(Float64, p2[:x]))^2)
    # println("(y1-y2)^2: ", (convert(Float64, p1[:y])-convert(Float64, p2[:y]))^2)
    # println("(z1-z2)^2: ", (convert(Float64, p1[:z])-convert(Float64, p2[:z]))^2)
    x1 = convert(Float64, p1[:x])
    x2 = convert(Float64, p2[:x])
    y1 = convert(Float64, p1[:y])
    y2 = convert(Float64, p2[:y])

    return sqrt(sum([(x1-x2)^2, (y1-y2)^2]))
end

function draw_graph(g)
    function position_layout(g)
        x:: Array{Float64} = []
        y:: Array{Float64} = []
        for v in vertices(g)
            if get_prop(g, v, :type) == "interior"
                neigh = interior_vertices(g, v)
                center = center_point((props(g, neigh[1]), props(g, neigh[2]), props(g, neigh[3])))
                push!(x, center[1])
                push!(y, center[2])
            else
                push!(x, get_prop(g, v, :x))
                push!(y, get_prop(g, v, :y))
            end
        end
        return x, y
    end
    # position_layout(g) = map((v) -> get_prop(g, v, :x), vertices(g)), map((v) -> get_prop(g, v, :y), vertices(g))

    labels = map((vertex) -> uppercase(get_prop(g, vertex, :type)[1]), 1:nv(g))

    edge_labels = []
    for edge in edges(g)
        if has_prop(g, edge, :length)
            push!(edge_labels, @sprintf("%.2f", get_prop(g, edge, :length)))
        else
            push!(edge_labels, "")
        end
    end

    edge_colors = []
    edge_width = []
    for edge in edges(g)
        if !has_prop(g, edge, :boundary)
            push!(edge_colors, colorant"yellow")
            push!(edge_width, 1.0)
        elseif get_prop(g, edge, :boundary)
            push!(edge_colors, colorant"lightgray")
            push!(edge_width, 3.0)
        else
            push!(edge_colors, colorant"lightgray")
            push!(edge_width, 1.0)
        end
    end

    vertex_size = []
    vertex_colors = []
    for vertex in 1:nv(g)
        if get_prop(g, vertex, :type) == "interior"
            push!(vertex_size, 0.6)
            if get_prop(g, vertex, :refine)
                push!(vertex_colors, colorant"orange")
            else
                push!(vertex_colors, colorant"yellow")
            end
        elseif get_prop(g, vertex, :type) == "vertex"
            push!(vertex_size, 1.0)
            push!(vertex_colors, colorant"lightgray")
        else
            push!(vertex_size, 1.0)
            push!(vertex_colors, colorant"gray")
        end
    end

    gplot(g,
        layout=position_layout,
        nodelabel=labels,
        nodefillc=vertex_colors,
        edgelabel=edge_labels,
        edgestrokec=edge_colors,
        edgelinewidth=edge_width,
        nodesize=vertex_size)
end

x(graph::AbstractMetaGraph, vertex::Integer)::Float64 = get_prop(graph, vertex, :x)
y(graph::AbstractMetaGraph, vertex::Integer)::Float64 = get_prop(graph, vertex, :y)
z(graph::AbstractMetaGraph, vertex::Integer)::Float64 = get_prop(graph, vertex, :z)

function draw_makie(g)
    labels = map((vertex) -> uppercase(get_prop(g, vertex, :type)[1]), 1:nv(g))

    edge_coords = Pair{Point{3,Float32},Point{3,Float32}}[]

    for edge in edges(g)
        p1 = edge.src
        p2 = edge.dst
        if get_prop(g, p1, :type) == "interior" || get_prop(g, p2, :type) == "interior"
            continue
        end
        push!(edge_coords, Point3f0(x(g, p1), y(g, p1), z(g, p1)) => Point3f0(x(g, p2), y(g, p2), z(g, p2)))
    end

    not_interior(g, v) = if get_prop(g, v, :type) == "interior" false else true end

    xs(graph::AbstractMetaGraph) = map((v) -> x(g, v), filter_vertices(graph, not_interior))
    ys(graph::AbstractMetaGraph) = map((v) -> y(g, v), filter_vertices(graph, not_interior))
    zs(graph::AbstractMetaGraph) = map((v) -> z(g, v), filter_vertices(graph, not_interior))

    scene = scatter(xs(g), ys(g), zs(g), color = :black, markersize = 0.1)
    linesegments!(scene, edge_coords)
    # TODO: proper coloring

    scene
end
