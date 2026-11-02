# --------------------------------------------------------------------------------
# Simulation configuration (*.tsim) and model parameters (*.grm)
# --------------------------------------------------------------------------------

"""
    MeSCoTConfig(; kwargs...) -> MeSCoTConfig

Simulation set-up, written to the `*.tsim` configuration file. Keyword
arguments (defaults follow the MeSCoT documentation):

| Keyword | Keyword in file | Meaning | Default |
| --- | --- | --- | --- |
| `snp` | `\$SNP` | Allele's data file name (mandatory) | - |
| `core` | `\$CORE` | Core SNPs data file name (mandatory) | - |
| `modelpar` | `\$MODELPAR` | Model parameters file name (mandatory) | `"model.grm"` |
| `remove` | `\$REMOVE` | Portion of the dynamic solution to remove, [0,1] | `0.2` |
| `all_genotypes` | `\$ALL` | Simulate all genotypes (`true`) or reference only | `true` |
| `reproduce` | `\$REPRODUCE` | Reproduce with saved RNG state | `false` |
| `rng` | `\$RNG` | Saved state of the random number generator | `0` |
| `nsaved` | `\$NSAVED` | Saved network file (optional) | `""` |
| `asaved` | `\$ASAVED` | Saved ACTIVATORS file (optional) | `""` |
| `rsaved` | `\$RSAVED` | Saved REPRESSORS file (optional) | `""` |
| `outres` | `\$OUTRES` | Output results folder name | `"Results"` |
| `results` | `\$RESULTS` | `"limited"` output, or full output when empty | `""` |

Use `simulate` to write the files and run MeSCoT, or `write_tsim` to only
write the configuration file.
"""
Base.@kwdef struct MeSCoTConfig
    snp::String = ""
    core::String = ""
    modelpar::String = "model.grm"
    remove::Float64 = 0.2
    all_genotypes::Bool = true
    reproduce::Bool = false
    rng::Int = 0
    nsaved::String = ""
    asaved::String = ""
    rsaved::String = ""
    outres::String = "Results"
    results::String = ""
end

"""Copy constructor: `MeSCoTConfig(config; kwargs...)` overrides selected fields."""
function MeSCoTConfig(c::MeSCoTConfig; kwargs...)
    defaults = (; (f => getfield(c, f) for f in fieldnames(MeSCoTConfig))...)
    return MeSCoTConfig(; merge(defaults, kwargs)...)
end

_with_modelpar(c::MeSCoTConfig, modelpar) = MeSCoTConfig(
    c.snp, c.core, modelpar, c.remove, c.all_genotypes, c.reproduce, c.rng,
    c.nsaved, c.asaved, c.rsaved, c.outres, c.results)

function _validate_config(c::MeSCoTConfig)
    errs = String[]
    isempty(c.snp) && push!(errs, "snp (\$SNP) must be set")
    isempty(c.core) && push!(errs, "core (\$CORE) must be set")
    isempty(c.modelpar) && push!(errs, "modelpar (\$MODELPAR) must be set")
    !(0 <= c.remove <= 1) && push!(errs, "remove must be in [0,1]")
    r = lowercase(c.results)
    r in ("", "limited") || push!(errs, "results must be \"\" (full) or \"limited\"")
    isempty(errs) && return nothing
    return join(errs, "; ")
end

"""Write one `# comment` / `\$KEYWORD` / `value` block."""
function _kw(io, keyword, value, comment)
    println(io, "# ", comment)
    println(io, "\$", keyword)
    println(io, value)
    println(io)
end

"""
    write_tsim(config::MeSCoTConfig, path::AbstractString) -> path

Write the MeSCoT simulation configuration (`*.tsim`) file.
"""
function write_tsim(c::MeSCoTConfig, path::AbstractString)
    err = _validate_config(c)
    err === nothing || error("Invalid MeSCoT configuration: " * err)
    open(path, "w") do io
        println(io, "# MeSCoT simulation configuration")
        println(io)
        _kw(io, "SNP", c.snp, "Allele's data file name")
        _kw(io, "CORE", c.core, "Core SNPs data file name")
        _kw(io, "MODELPAR", c.modelpar, "Model parameters file name")
        _kw(io, "REMOVE", string(c.remove),
            "Amount of data to remove from dynamic solution, val = [0,1]")
        _kw(io, "ALL", c.all_genotypes ? "1" : "0",
            "Simulate for all genotypes, otherwise only for reference genotype, val = 1|0")
        _kw(io, "REPRODUCE", c.reproduce ? "1" : "0",
            "Reproduce simulation with saved state of random number generator, val = 1|0")
        _kw(io, "RNG", string(c.rng), "Saved state of random number generator")
        _kw(io, "NSAVED", c.nsaved, "Saved network file name (if it is going to be used for simulation)")
        _kw(io, "ASAVED", c.asaved, "Saved ACTIVATORS file name (if it is going to be used for simulation)")
        _kw(io, "RSAVED", c.rsaved, "Saved REPRESSORS file name (if it is going to be used for simulation)")
        _kw(io, "OUTRES", c.outres, "Optional output results path")
        isempty(c.results) ||
            _kw(io, "RESULTS", c.results, "Type of output results: limited (or full by default)")
    end
    return path
end

"""
    ModelParameters(; kwargs...) -> ModelParameters

Parameters of the MeSCoT gene regulation model, written to the `*.grm` model
parameters file. Keyword arguments (defaults follow the MeSCoT documentation):

| Keyword | In file | Meaning | Default |
| --- | --- | --- | --- |
| `arch` | `\$ARCH` | Network architecture type: `downstream` or `upstream` | `"downstream"` |
| `n1`,`n2`,`n3` | `\$N1..\$N3` | Portion of genes in basal network of type 1,2,3, [0,1] | `0.0` |
| `beta1`,`beta2`,`beta3` | `\$BETA1..3` | Network configuration parameters, [0,10] | `0.1` |
| `merge` | `\$MERGE` | Random contacts between basal networks, [0,inf) | `1.0` |
| `mode` | `\$MODE` | A/R setting: `strict`, `mix` or `tf` | `"strict"` |
| `ratio` | `\$RATIO` | Proportion of activators vs repressors, [0,1] | `0.5` |
| `raterna` | `\$RATERNA` | Transcription rate [1/min] | `4.0` |
| `ratep` | `\$RATEP` | Translation rate [1/min] | `8.0` |
| `degrna` | `\$DEGRNA` | mRNA degradation rate [1/min] | `0.2` |
| `degp` | `\$DEGP` | Protein degradation rate [1/min] | `0.6` |
| `ebind` | `\$EBIND` | Pol II binding energy [kT], [0,11] | `9.0` |
| `kbind` | `\$KBIND` | Pol II binding constant [1/kT] | `8.1e3` |
| `kact` | `\$KACT` | Activator binding constant [1/kT] | `5.0e5` |
| `eact` | `\$EACT` | Activator binding energy [kT], [0,11] | `6.0` |
| `krep` | `\$KREP` | Repressor binding constant [1/kT] | `5.0e2` |
| `erep` | `\$EREP` | Repressor binding energy [kT], [0,11] | `7.0` |
| `tmax` | `\$TMAX` | Max time of dynamic solution [min] | `500.0` |
| `tdil` | `\$TDIL` | Time delay from diffusion [min] | `0.0` |
| `stoch` | `\$STOCH` | Stochastic perturbation of dynamics, [0,1] | `0.0` |
| `gendiff` | `\$GENDIFF` | Among-gene heterogeneity of rates, [0,1] | `0.0` |
| `snpdiff` | `\$SNPDIFF` | SNP polymorphism response, [0,1] | `0.25` |
"""
Base.@kwdef struct ModelParameters
    arch::String = "downstream"
    n1::Float64 = 0.0
    n2::Float64 = 0.0
    n3::Float64 = 0.0
    beta1::Float64 = 0.1
    beta2::Float64 = 0.1
    beta3::Float64 = 0.1
    merge::Float64 = 1.0
    mode::String = "strict"
    ratio::Float64 = 0.5
    raterna::Float64 = 4.0
    ratep::Float64 = 8.0
    degrna::Float64 = 0.2
    degp::Float64 = 0.6
    ebind::Float64 = 9.0
    kbind::Float64 = 8.1e3
    kact::Float64 = 5.0e5
    eact::Float64 = 6.0
    krep::Float64 = 5.0e2
    erep::Float64 = 7.0
    tmax::Float64 = 500.0
    tdil::Float64 = 0.0
    stoch::Float64 = 0.0
    gendiff::Float64 = 0.0
    snpdiff::Float64 = 0.25
end

"""
    write_grm(model::ModelParameters, path::AbstractString) -> path

Write the MeSCoT model parameters (`*.grm`) file.
"""
function write_grm(m::ModelParameters, path::AbstractString)
    open(path, "w") do io
        println(io, "# MeSCoT model parameters")
        println(io)
        println(io, "# ------------------------------------------------------------------")
        println(io, "# GENE NETWORK PARAMETERS")
        println(io, "# ------------------------------------------------------------------")
        _kw(io, "ARCH", m.arch, "archType = downstream|upstream: type of GN Architecture")
        _kw(io, "N1", string(m.n1), "genes_ntw1 = [0,1]: portion of genes of basal network of type 1")
        _kw(io, "N2", string(m.n2), "genes_ntw2 = [0,1]: portion of genes of basal network of type 2")
        _kw(io, "N3", string(m.n3), "genes_ntw3 = [0,1]: portion of genes of basal network of type 3")
        _kw(io, "BETA1", string(m.beta1), "beta_ntw1 = [0 10]: network configuration parameter of type 1 network")
        _kw(io, "BETA2", string(m.beta2), "beta_ntw2 = [0 10]: network configuration parameter of type 2 network")
        _kw(io, "BETA3", string(m.beta3), "beta_ntw3 = [0 10]: network configuration parameter of type 3 network")
        _kw(io, "MERGE", string(m.merge), "mergingStrength = [0, +inf]: random contacts between basal networks")
        _kw(io, "MODE", m.mode, "Mode of Activator(A)|Repressor(R) setting: strict|mix|tf")
        _kw(io, "RATIO", string(m.ratio),
            "val = [0,1]: proportion of activators/repressors in network " *
            "(0.0 - all TF are R, 1.0 - all TF are A)")
        println(io, "# ------------------------------------------------------------------")
        println(io, "# GENE REGULATION MODEL PARAMETERS")
        println(io, "# ------------------------------------------------------------------")
        _kw(io, "RATERNA", string(m.raterna), "Transcription RATE (k_rna) for a reference gene, [1/min]")
        _kw(io, "RATEP", string(m.ratep), "Translation RATE (k_p) for a reference gene, [1/min]")
        _kw(io, "DEGRNA", string(m.degrna), "mRNA degradation RATE (g_rna) for a reference gene, [1/min]")
        _kw(io, "DEGP", string(m.degp), "Protein degradation RATE (g_p) for a reference gene, [1/min]")
        _kw(io, "EBIND", string(m.ebind), "Polymerase_II complex binding ENERGY (G_bind) for a reference gene, [kT]")
        _kw(io, "KBIND", string(m.kbind), "Polymerase_II complex binding CONSTANT (k_bind) for a reference gene, [1/kT]")
        _kw(io, "KACT", string(m.kact), "Activator's complex binding CONSTANT (k_act) for a reference gene, [1/kT]")
        _kw(io, "EACT", string(m.eact), "Activator's complex binding ENERGY (G_act) for a reference gene, [kT]")
        _kw(io, "KREP", string(m.krep), "Repressor's complex binding CONSTANT (k_rep) for a reference gene, [1/kT]")
        _kw(io, "EREP", string(m.erep), "Repressor's complex binding ENERGY (G_rep) for a reference gene, [kT]")
        _kw(io, "TMAX", string(m.tmax), "Max time (T_max) of dynamic solution, [min]")
        _kw(io, "TDIL", string(m.tdil), "Time delay (T_d) due to mRNA and protein diffusion, [min]")
        _kw(io, "STOCH", string(m.stoch),
            "Stochastic perturbation to dynamic solution (perturbation p_v from N(0,p_v), p_v << 1)")
        _kw(io, "GENDIFF", string(m.gendiff),
            "Strength of difference among genes properties in network (sd of k_rna|k_p|g_rna|g_p)")
        _kw(io, "SNPDIFF", string(m.snpdiff), "Efficiency of SNP polymorphism (SNP response parameter)")
    end
    return path
end

"""
    parse_tsim(path::AbstractString) -> Dict{String,String}

Parse a MeSCoT keyword/value file (`*.tsim` or `*.grm`) into a dictionary
keyed by the keyword without the leading `\$` (e.g. `"SNP" => "data/rand_allele.dat"`).
Comments (`# ...`) and empty lines are ignored.
"""
function parse_tsim(path::AbstractString)
    kw = ""
    d = Dict{String,String}()
    for line in eachline(path)
        s = strip(line)
        (isempty(s) || startswith(s, "#")) && continue
        if startswith(s, "\$")
            kw = String(s[2:end])
        elseif !isempty(kw)
            haskey(d, kw) || (d[kw] = String(s))
            kw = ""
        end
    end
    return d
end

