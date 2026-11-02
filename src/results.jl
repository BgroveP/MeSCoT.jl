# --------------------------------------------------------------------------------
# Output readers
# --------------------------------------------------------------------------------

"""
Numeric directories of simulated genotypes under a results folder
(full output writes one folder per genotype: `\$OUTRES/<genotype_id>/`).
"""
function _genotype_dirs(outdir)
    out = Tuple{Int,String}[]
    isdir(outdir) || return out
    for e in readdir(outdir; join = true)
        isdir(e) || continue
        n = tryparse(Int, basename(e))
        n === nothing || push!(out, (n, e))
    end
    sort!(out; by = first)
    return [d for (_, d) in out]
end

"""Locate an output file: the requested genotype folder, the results folder
itself, or the first genotype folder that has the file."""
function _find_result_file(r::MeSCoTResult, name; genotype = nothing)
    if genotype !== nothing
        f = joinpath(r.outdir, string(genotype), name)
        isfile(f) && return f
    end
    f = joinpath(r.outdir, name)
    isfile(f) && return f
    for gd in _genotype_dirs(r.outdir)
        f = joinpath(gd, name)
        isfile(f) && return f
    end
    error("Could not find $(name) in the results at $(r.outdir)" *
          (genotype === nothing ? "" : " for genotype $(genotype)"))
end

"""Locate the core gene products file (named `products_<range>.txt` for
multi-genotype runs)."""
function _find_products_file(outdir)
    isdir(outdir) || error("Results folder not found: $(outdir)")
    cands = sort(collect(f for f in readdir(outdir; join = true)
                 if isfile(f) && startswith(basename(f), "products") &&
                    endswith(basename(f), ".txt")))
    isempty(cands) || return first(cands)
    for gd in _genotype_dirs(outdir)
        f = joinpath(gd, "products.txt")
        isfile(f) && return f
    end
    error("No core gene products file found under $(outdir)")
end

"""
    read_traits(path) -> (id = Vector{Int}, value = Vector{Float64})

Read the genomic values file (`traits.txt`): `[genotype_id] [value]`.
Also accepts a `MeSCoTResult`.
"""
function read_traits(path::AbstractString)
    id = Int[]
    value = Float64[]
    for line in eachline(path)
        s = strip(line)
        (isempty(s) || startswith(s, "#")) && continue
        parts = split(s)
        length(parts) >= 2 || error("traits line must have >= 2 columns: $(line)")
        push!(id, parse(Int, parts[1]))
        push!(value, parse(Float64, parts[end]))
    end
    return (id = id, value = value)
end
read_traits(r::MeSCoTResult) = read_traits(joinpath(r.outdir, "traits.txt"))

"""
    read_ref_trait(r::MeSCoTResult) -> (id, value)

Read the reference genotype genomic value file (`ref_trait.txt`).
"""
read_ref_trait(r::MeSCoTResult) = read_traits(joinpath(r.outdir, "ref_trait.txt"))

"""
    read_time(path) -> Vector{Float64}

Read the time range of the dynamic solution (`time.txt`: time points
separated with spaces, typically one long line). Also accepts a
`MeSCoTResult`, in which case the file is located in (or under) the
results folder.
"""
function read_time(path::AbstractString)
    t = Float64[]
    for line in eachline(path)
        s = strip(line)
        (isempty(s) || startswith(s, "#")) && continue
        append!(t, parse.(Float64, split(s)))
    end
    return t
end
function read_time(r::MeSCoTResult; genotype = nothing)
    return read_time(_find_result_file(r, "time.txt"; genotype = genotype))
end

"""
    GeneData(snp, gene, values)

Time series output for genes (`rna.txt`, `p.txt`, `products.txt`):
one row per gene, `[snp_id] [network_gene_id] [values separated with
spaces]`, with `values` a `n_genes x n_time` matrix.
"""
struct GeneData
    snp::Vector{Int}
    gene::Vector{Int}
    values::Matrix{Float64}
end

"""
    read_gene_data(path) -> GeneData

Read a per-gene time series file (`rna.txt`, `p.txt` or `products.txt`).
The result-based variants `read_rna`, `read_p` and `read_products` locate
the file inside a [`MeSCoTResult`](@ref).
"""
function read_gene_data(path::AbstractString)
    snp = Int[]
    gene = Int[]
    rows = Vector{Float64}[]
    for line in eachline(path)
        s = strip(line)
        (isempty(s) || startswith(s, "#")) && continue
        parts = split(s)
        length(parts) >= 3 || error("gene data line must have >= 3 columns: $(line)")
        push!(snp, parse(Int, parts[1]))
        push!(gene, parse(Int, parts[2]))
        push!(rows, parse.(Float64, parts[3:end]))
    end
    isempty(rows) && error("No data rows in $(path)")
    ncol = length(first(rows))
    all(r -> length(r) == ncol, rows) ||
        error("Inconsistent number of value columns in $(path)")
    values = permutedims(reduce(hcat, rows))
    return GeneData(snp, gene, Matrix{Float64}(values))
end

"""
    read_rna(r::MeSCoTResult; genotype = nothing) -> GeneData

Read the genes' mRNA file (`rna.txt`). With full output, time series are
written per genotype (`\$OUTRES/<genotype_id>/rna.txt`); pass `genotype` to
select one, otherwise the first available is read.
"""
function read_rna(r::MeSCoTResult; genotype = nothing)
    return read_gene_data(_find_result_file(r, "rna.txt"; genotype = genotype))
end

"""
    read_p(r::MeSCoTResult; genotype = nothing) -> GeneData

Read the genes' protein file (`p.txt`); see [`read_rna`](@ref) for the
`genotype` argument.
"""
function read_p(r::MeSCoTResult; genotype = nothing)
    return read_gene_data(_find_result_file(r, "p.txt"; genotype = genotype))
end

"""
    read_products(r::MeSCoTResult) -> GeneData

Read the core gene product file (`products.txt` / `products_<range>.txt`
in the results folder).
"""
function read_products(r::MeSCoTResult)
    return read_gene_data(_find_products_file(r.outdir))
end

