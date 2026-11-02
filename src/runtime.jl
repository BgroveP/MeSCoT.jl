# --------------------------------------------------------------------------------
# MATLAB Runtime resolution
# --------------------------------------------------------------------------------

"""Version-folder names a MATLAB Runtime root could use for `release`
(installers use dotless names like `v92`; the dotted form is also accepted)."""
_version_dir_candidates(release) =
    unique([MatlabRuntime_jll.version_dir(release),             # "v92"
            "v" * MatlabRuntime_jll.release_version(release)])   # "v9.2"

"""Accept a root given either as the runtime root or as the version folder
itself (e.g. `.../MATLAB_Runtime` or `.../MATLAB_Runtime/v92`)."""
function _normalize_root(root; release)
    root = normpath(expanduser(root))
    if basename(root) in _version_dir_candidates(release)
        return dirname(root)
    end
    return root
end

"""
    runtime_root(; root = nothing, release = MESCOT_RUNTIME_RELEASE) -> String

Root directory of the MATLAB Runtime installation that MeSCoT runs against
(the directory containing the `v92` runtime folder for R2017a).

Resolution order:

1. the `root` argument,
2. the environment variable `MESCOT_RUNTIME_ROOT`,
3. an existing installation found by `MatlabRuntime_jll.find_system_runtime`
   (this also honours `MATLABRUNTIME_JLL_ROOT` / `MCR_ROOT`), accepting only
   a tree that actually contains the requested release's runtime,
4. a package-managed `MatlabRuntime_jll` installation.

MeSCoT is compiled with MATLAB R2017a, so it needs runtime version 9.2
(folder `v92`). MathWorks no longer distributes runtimes that old, so they
cannot be downloaded automatically: point MeSCoT at an existing installation
via `root`, `MESCOT_RUNTIME_ROOT` or `MATLABRUNTIME_JLL_ROOT`, or install it
under a standard location (`/usr/local/MATLAB/MATLAB_Runtime` on Linux,
`%ProgramFiles%\\MATLAB\\MATLAB Runtime` on Windows).
"""
function runtime_root(; root = nothing, release = MESCOT_RUNTIME_RELEASE)
    release = string(release)
    root === nothing || return _normalize_root(string(root); release)
    env = get(ENV, "MESCOT_RUNTIME_ROOT", "")
    isempty(env) || return _normalize_root(env; release)
    sys = MatlabRuntime_jll.find_system_runtime(; release = release)
    sys === nothing || return sys
    if MatlabRuntime_jll.is_installed(release, "0")
        return MatlabRuntime_jll.mcr_root(; release = release, update = "0",
                                           autoinstall = false)
    end
    error("MeSCoT needs the MATLAB Runtime for MATLAB $(release) " *
          "(version $(MatlabRuntime_jll.release_version(release)), folder " *
          "\"$(MatlabRuntime_jll.version_dir(release))\"), and MathWorks no longer " *
          "distributes it. Set MESCOT_RUNTIME_ROOT (or MATLABRUNTIME_JLL_ROOT) to " *
          "the runtime root directory - the folder that contains " *
          "\"$(MatlabRuntime_jll.version_dir(release))\" - or install the " *
          "MATLAB Runtime $(release) to a standard location " *
          "(/usr/local/MATLAB/MATLAB_Runtime on Linux, " *
          "%ProgramFiles%\\MATLAB\\MATLAB Runtime on Windows).")
end

"""
    runtime_version_dir(; root = runtime_root()) -> String

The runtime version directory under `root` (e.g. `.../v92`), the directory the
official `run_mescot.sh` / `run_mescot.bat` launchers expect as their
`<mcr_directory>` argument.
"""
function runtime_version_dir(; root = runtime_root(),
                             release = MESCOT_RUNTIME_RELEASE)
    root = string(root)
    for c in _version_dir_candidates(release)
        isdir(joinpath(root, c)) && return joinpath(root, c)
    end
    dirs = [joinpath(root, d) for d in readdir(root)
            if isdir(joinpath(root, d)) && occursin(r"^v\d+(\.\d+)*$", d)]
    isempty(dirs) && error("No v<version> runtime directory found under $(root)")
    return first(dirs)
end

