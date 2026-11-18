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
    runtime_root(; root = nothing, release = MESCOT_RUNTIME_RELEASE,
                 autoinstall = true) -> String

Root directory of the MATLAB Runtime installation that MeSCoT runs against
(the directory containing the `v92` runtime folder for R2017a).

Resolution order:

1. the `root` argument,
2. the environment variable `MESCOT_RUNTIME_ROOT`,
3. an existing installation found by `MatlabRuntime_jll.find_system_runtime`
   (this also honours `MATLABRUNTIME_JLL_ROOT` / `MCR_ROOT`), accepting only
   a tree that actually contains the requested release's runtime,
4. a package-managed `MatlabRuntime_jll` installation,
5. if `autoinstall` is true, a fresh package-managed installation via
   [`install_runtime`](@ref) (downloads the ~1.3 GB MathWorks installer once).

MeSCoT is compiled with MATLAB R2017a, so it needs runtime version 9.2
(folder `v92`).
"""
function runtime_root(; root = nothing, release = MESCOT_RUNTIME_RELEASE,
                      autoinstall = true)
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
    autoinstall && return install_runtime(; release = release)
    error("No MATLAB Runtime $(release) (version " *
          "$(MatlabRuntime_jll.release_version(release)), folder " *
          "\"$(MatlabRuntime_jll.version_dir(release))\") was found. Run " *
          "`install_runtime()` to download and install it, or set " *
          "MESCOT_RUNTIME_ROOT (or MATLABRUNTIME_JLL_ROOT) to an existing runtime " *
          "root directory - the folder that contains " *
          "\"$(MatlabRuntime_jll.version_dir(release))\".")
end

"""
    install_runtime(; release = MESCOT_RUNTIME_RELEASE, force = false) -> String

Download and install the MATLAB Runtime MeSCoT needs (R2017a, `v92`) into the
`MatlabRuntime_jll` scratch space, using the MathWorks installer (~1.3 GB
download, several GB on disk). Returns the runtime root. On Windows the
installer asks for administrator rights (one UAC prompt).
"""
function install_runtime(; release = MESCOT_RUNTIME_RELEASE, force = false)
    release = string(release)
    @info "Installing the MATLAB Runtime $(release) required by MeSCoT " *
          "(one-time download of ~1.3 GB; this takes several minutes)"
    return MatlabRuntime_jll.install(; release = release, update = "0",
                                      force = force)
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

