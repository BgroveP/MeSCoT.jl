# --------------------------------------------------------------------------------
# Input data files
# --------------------------------------------------------------------------------

"""
    SnpData(id, chip, alleles)

SNP variant data (`*.dat` allele data file): `id` and `chip` are the first two
columns, `alleles` (a matrix of `0/1/2`) the remaining columns.
"""
struct SnpData
    id::Vector{Int}
    chip::Vector{Int}
    alleles::Matrix{Int}
end

"""
    read_snp_data(path::AbstractString) -> SnpData

Read the MeSCoT allele data file (`\$SNP`): lines of
`[genotype_id] [chip_id] [allele variants separated with spaces]`.
"""
function read_snp_data(path::AbstractString)
    id = Int[]
    chip = Int[]
    rows = Vector{Int}[]
    for line in eachline(path)
        s = strip(line)
        (isempty(s) || startswith(s, "#")) && continue
        vals = [parse(Int, x) for x in split(s)]
        length(vals) >= 3 ||
            error("SNP data line must have at least 3 columns: $(line)")
        push!(id, vals[1])
        push!(chip, vals[2])
        push!(rows, vals[3:end])
    end
    isempty(rows) && error("No data rows in $(path)")
    ncol = length(first(rows))
    all(r -> length(r) == ncol, rows) ||
        error("Inconsistent number of allele columns in $(path)")
    alleles = permutedims(reduce(hcat, rows))  # n_genotypes x n_snps
    return SnpData(id, chip, Matrix{Int}(alleles))
end

"""
    write_snp_data(data::SnpData, path::AbstractString) -> path

Write the MeSCoT allele data file (`\$SNP`).
"""
function write_snp_data(data::SnpData, path::AbstractString)
    open(path, "w") do io
        for i in eachindex(data.id)
            println(io, data.id[i], " ", data.chip[i], " ",
                    join(view(data.alleles, i, :), " "))
        end
    end
    return path
end

"""
    CoreSnpData(snp, weight)

Core SNP data (`\$CORE` file): list of QTLs (SNP ids) associated with core
genes, with a weight per entry.
"""
struct CoreSnpData
    snp::Vector{Int}
    weight::Vector{Float64}
end

"""
    read_core_data(path::AbstractString) -> CoreSnpData

Read the MeSCoT core SNP data file (`\$CORE`): lines of `[snp_id] [weight]`.
"""
function read_core_data(path::AbstractString)
    snp = Int[]
    weight = Float64[]
    for line in eachline(path)
        s = strip(line)
        (isempty(s) || startswith(s, "#")) && continue
        parts = split(s)
        length(parts) == 2 || error("Core SNP line must be [snp_id] [weight]: $(line)")
        push!(snp, parse(Int, parts[1]))
        push!(weight, parse(Float64, parts[2]))
    end
    return CoreSnpData(snp, weight)
end

"""
    write_core_data(data::CoreSnpData, path::AbstractString) -> path

Write the MeSCoT core SNP data file (`\$CORE`).
"""
function write_core_data(data::CoreSnpData, path::AbstractString)
    open(path, "w") do io
        for i in eachindex(data.snp)
            println(io, data.snp[i], " ", data.weight[i])
        end
    end
    return path
end

"""
    GeneNetwork(from, to, weight)

Gene regulatory network geometry (`*.gntw` file, e.g. the saved network files
`\$NSAVED` / `\$ASAVED` / `\$RSAVED`): one contact per row,
`[gene_id] [target_gene_id] [weight]`.
"""
struct GeneNetwork
    from::Vector{Int}
    to::Vector{Int}
    weight::Vector{Float64}
end

"""
    read_network(path::AbstractString) -> GeneNetwork

Read a MeSCoT network file (`*.gntw`).
"""
function read_network(path::AbstractString)
    from = Int[]
    to = Int[]
    weight = Float64[]
    for line in eachline(path)
        s = strip(line)
        (isempty(s) || startswith(s, "#")) && continue
        parts = split(s)
        length(parts) == 3 ||
            error("Network line must be [gene_id] [gene_id] [weight]: $(line)")
        push!(from, parse(Int, parts[1]))
        push!(to, parse(Int, parts[2]))
        push!(weight, parse(Float64, parts[3]))
    end
    return GeneNetwork(from, to, weight)
end

"""
    write_network(net::GeneNetwork, path::AbstractString) -> path

Write a MeSCoT network file (`*.gntw`).
"""
function write_network(net::GeneNetwork, path::AbstractString)
    open(path, "w") do io
        for i in eachindex(net.from)
            println(io, net.from[i], "\t", net.to[i], "\t", net.weight[i])
        end
    end
    return path
end

