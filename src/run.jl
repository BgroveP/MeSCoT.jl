# --------------------------------------------------------------------------------
# Running simulations
# --------------------------------------------------------------------------------

"""
Environment for launching the MeSCoT executable: the MATLAB Runtime library
directories (via `MatlabRuntime_jll.mcr_env`), plus the application directory
and the working directory, mirroring the official `run_mescot.sh` launcher.
"""
function _launch_env(exe, root)
    env = copy(ENV)
    var = Sys.iswindows() ? "PATH" : "LD_LIBRARY_PATH"
    parts = String[dirname(exe), "."]
    me = MatlabRuntime_jll.mcr_env(root)
    if haskey(me, var)
        push!(parts, me[var])
    else
        for v in values(me)
            push!(parts, v)
        end
    end
    prev = get(env, var, "")
    isempty(prev) || push!(parts, prev)
    env[var] = join(parts, _PATHSEP)
    return env
end

"""
Result of a MeSCoT run: the working directory `dir`, the results folder
`outdir` (the `\$OUTRES` path of the configuration) and the `config` file.
Readers such as `read_traits` accept a `MeSCoTResult` directly.

With full output, `outdir` contains `traits.txt` (genomic values per
genotype), `products_<range>.txt` (core gene products), the saved network
geometry (`*.gntw`), the reference genotype results (`ref_trait.txt`,
`ref_products.txt`) and one folder per simulated genotype
(`\$OUTRES/<genotype_id>/`) with the per-gene time series (`rna.txt`,
`p.txt`, `time.txt`).
"""
struct MeSCoTResult
    dir::String
    outdir::String
    config::String
end

result_dir(r::MeSCoTResult) = r.outdir

"""
    run_mescot(config::AbstractString; dir = pwd(), root = nothing,
               release = MESCOT_RUNTIME_RELEASE) -> MeSCoTResult

Run the MeSCoT application with the given `*.tsim` configuration file,
using the MATLAB Runtime resolved by [`runtime_root`](@ref).

`dir` is the working directory of the simulation: paths in the configuration
file are resolved relative to it, and outputs (`\$OUTRES` folder,
`mescot_runtime.log`) are written there. `root` overrides the runtime root.

The executable is invoked directly with the same environment the official
`run_mescot.sh` / `run_mescot.bat` launchers set up, so no launcher script is
needed. MeSCoT prints its progress to stdout/stderr; on failure the error
message points at `mescot_runtime.log` in `dir`.
"""
function run_mescot(config::AbstractString; dir = pwd(), root = nothing,
                   release = MESCOT_RUNTIME_RELEASE)
    cfgfile = normpath(abspath(expanduser(config)))
    isfile(cfgfile) || error("MeSCoT configuration file not found: $(cfgfile)")
    dir = normpath(abspath(expanduser(dir)))
    mkpath(dir)
    exe = app_exe()
    rtroot = runtime_root(; root = root, release = release)
    parsed = parse_tsim(cfgfile)
    cmd = setenv(`$(exe) $(cfgfile)`, _launch_env(exe, rtroot))
    @info "Running MeSCoT" config = cfgfile dir root = rtroot
    cd(dir) do
        try
            run(cmd)
        catch err
            err isa ProcessFailedException || rethrow()
            error("MeSCoT exited with an error; see the output above and " *
                  "$(joinpath(dir, "mescot_runtime.log")) for details.")
        end
    end
    outres = get(parsed, "OUTRES", "Results")
    outdir = isabspath(outres) ? outres : normpath(joinpath(dir, outres))
    return MeSCoTResult(dir, outdir, cfgfile)
end

"""
    run_mescot(config::MeSCoTConfig; dir = pwd(), kwargs...) -> MeSCoTResult

Write `config` to `config.tsim` in `dir` (the referenced `\$MODELPAR` file
must already exist there) and run MeSCoT.
"""
function run_mescot(c::MeSCoTConfig; dir = pwd(), kwargs...)
    err = _validate_config(c)
    err === nothing || error("Invalid MeSCoT configuration: " * err)
    dir = normpath(abspath(expanduser(dir)))
    mkpath(dir)
    f = joinpath(dir, "config.tsim")
    write_tsim(c, f)
    return run_mescot(f; dir = dir, kwargs...)
end

"""
    simulate(config::MeSCoTConfig, model = ModelParameters();
             dir = mktempdir(), root = nothing,
             release = MESCOT_RUNTIME_RELEASE) -> MeSCoTResult

High-level entry point: write the model parameters file (`model.grm` unless
`config.modelpar` says otherwise) and the configuration file into `dir`,
run MeSCoT, and return a [`MeSCoTResult`](@ref).

Example:

```julia
using MeSCoT

sim = MeSCoTConfig(snp = "data/rand_allele.dat",
                   core = "data/rand_core.dat",
                   outres = "GxG_results")
model = ModelParameters(n1 = 1.0, beta1 = 0.02, mode = "mix", ratio = 0.7,
                        snpdiff = 0.25)
result = simulate(sim, model)
traits = read_traits(result)
```
"""
function simulate(c::MeSCoTConfig, m::ModelParameters = ModelParameters();
                  dir = mktempdir(), root = nothing,
                  release = MESCOT_RUNTIME_RELEASE)
    err = _validate_config(c)
    err === nothing || error("Invalid MeSCoT configuration: " * err)
    dir = normpath(abspath(expanduser(dir)))
    modelpar = isempty(c.modelpar) ? "model.grm" : c.modelpar
    c = _with_modelpar(c, modelpar)
    mpfile = normpath(joinpath(dir, modelpar))
    mkpath(dirname(mpfile))
    write_grm(m, mpfile)
    return run_mescot(c; dir = dir, root = root, release = release)
end

