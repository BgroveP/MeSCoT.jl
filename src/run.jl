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

"""Input-file keywords of a `*.tsim` configuration (optional ones may be empty)."""
const _INPUT_KEYWORDS = ("SNP", "CORE", "MODELPAR", "NSAVED", "ASAVED", "RSAVED")

"""Fail early, with a clear message, when an input file named in the
configuration does not exist. Relative paths are resolved against `dir`, the
directory MeSCoT runs in."""
function _check_input_files(parsed, dir)
    missing_files = String[]
    for key in _INPUT_KEYWORDS
        f = strip(get(parsed, key, ""))
        isempty(f) && continue
        path = isabspath(f) ? f : normpath(joinpath(dir, f))
        isfile(path) || push!(missing_files, "\$$(key) = \"$(f)\" -> $(path)")
    end
    isempty(missing_files) && return nothing
    error("MeSCoT input file(s) not found:\n  " * join(missing_files, "\n  ") *
          "\nPaths given to MeSCoTConfig are resolved against the Julia working " *
          "directory ($(pwd())); relative paths inside a .tsim file passed to " *
          "run_mescot are resolved against the simulation directory `dir` ($(dir)).")
end

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
    parsed = parse_tsim(cfgfile)
    _check_input_files(parsed, dir)
    exe = app_exe()
    rtroot = runtime_root(; root = root, release = release)
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

"""Absolute form of an input path given relative to `base` (empty stays empty)."""
_abs_input(f, base) = isempty(f) ? f : normpath(joinpath(base, expanduser(f)))

"""Copy of `c` whose input file paths are absolute, resolved against `base`
(the Julia working directory). `\$MODELPAR` is resolved too unless
`modelpar = false` (when `simulate` writes it into the run directory)."""
function _resolve_inputs(c::MeSCoTConfig; base = pwd(), modelpar = true)
    return MeSCoTConfig(c;
        snp = _abs_input(c.snp, base),
        core = _abs_input(c.core, base),
        modelpar = modelpar ? _abs_input(c.modelpar, base) : c.modelpar,
        nsaved = _abs_input(c.nsaved, base),
        asaved = _abs_input(c.asaved, base),
        rsaved = _abs_input(c.rsaved, base))
end

"""Write `c` (paths already resolved) to `config.tsim` in `dir` and run it."""
function _run_config(c::MeSCoTConfig, dir; kwargs...)
    mkpath(dir)
    f = joinpath(dir, "config.tsim")
    write_tsim(c, f)
    return run_mescot(f; dir = dir, kwargs...)
end

"""
    run_mescot(config::MeSCoTConfig; dir = pwd(), kwargs...) -> MeSCoTResult

Write `config` to `config.tsim` in `dir` and run MeSCoT there.

Input file paths in `config` (`snp`, `core`, `modelpar`, `nsaved`, `asaved`,
`rsaved`) are resolved relative to the current Julia working directory
(`pwd()`), not `dir`; they are written to the configuration file as absolute
paths. The `outres` results folder is created inside `dir`.
"""
function run_mescot(c::MeSCoTConfig; dir = pwd(), kwargs...)
    err = _validate_config(c)
    err === nothing || error("Invalid MeSCoT configuration: " * err)
    dir = normpath(abspath(expanduser(dir)))
    return _run_config(_resolve_inputs(c), dir; kwargs...)
end

"""
    simulate(config::MeSCoTConfig, model = ModelParameters();
             dir = mktempdir(), root = nothing,
             release = MESCOT_RUNTIME_RELEASE) -> MeSCoTResult

High-level entry point: write the model parameters file (`model.grm` unless
`config.modelpar` says otherwise) and the configuration file into `dir`,
run MeSCoT, and return a [`MeSCoTResult`](@ref).

Input data paths in `config` (`snp`, `core`, `nsaved`, `asaved`, `rsaved`)
are resolved relative to the current Julia working directory (`pwd()`), so
`dir` can be anywhere. `modelpar` and `outres` are locations inside `dir`.

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
    c = _resolve_inputs(_with_modelpar(c, modelpar); modelpar = false)
    mpfile = normpath(joinpath(dir, modelpar))
    mkpath(dirname(mpfile))
    write_grm(m, mpfile)
    return _run_config(c, dir; root = root, release = release)
end
