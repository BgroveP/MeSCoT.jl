# --------------------------------------------------------------------------------
# MeSCoT application: download and install into the package scratch space
# --------------------------------------------------------------------------------

_scratch() = @get_scratch!("mescot")
_app_root() = joinpath(_scratch(), "app")
_archive() = joinpath(_scratch(), basename(MESCOT_URL))

"""Locate the `mescot(.exe)` executable under `root` (the downloaded archive
extracts it into a platform subfolder, e.g. `mescot_lin/`)."""
function _find_app_exe(root; quiet = false)
    for (d, dirs, files) in walkdir(root)
        for f in files
            lowercase(f) in ("mescot.exe", "mescot") && return joinpath(d, f)
        end
    end
    quiet && return nothing
    error("No MeSCoT executable found under $(root)")
end

"""
    is_app_installed() -> Bool

Whether the MeSCoT application is downloaded and extracted into the package
scratch space.
"""
function is_app_installed()
    root = _app_root()
    isfile(joinpath(root, MARKER)) || return false
    return _find_app_exe(root; quiet = true) !== nothing
end

"""
    install_app(; force = false, keep_archive = false) -> String

Download the MeSCoT application (~68 MiB) from the official download page and
extract it into the package scratch space. Returns the directory containing
the executable. Reuses a previously downloaded archive if it is complete.
"""
function install_app(; force = false, keep_archive = false)
    _platform()
    root = _app_root()
    if !force && is_app_installed()
        @info "MeSCoT application is already installed at $(root)"
        return app_dir()
    end
    @info "Downloading the MeSCoT application" url = MESCOT_URL
    zip = _archive()
    # Reuses an existing archive when its size matches the server's
    # Content-Length (protects against re-downloading after a failed run).
    MatlabRuntime_jll._ensure_downloaded(MESCOT_URL, zip)
    rm(root; recursive = true, force = true)
    mkpath(root)
    @info "Extracting the MeSCoT application archive"
    MatlabRuntime_jll._extract(zip, root)
    exe = _find_app_exe(root)
    chmod(exe, 0o755)
    touch(joinpath(root, MARKER))
    keep_archive || rm(zip; force = true)
    @info "MeSCoT application installed at $(app_dir())"
    return app_dir()
end

"""Ensure the application is present and return the path of the executable."""
function app_exe()
    exe = _find_app_exe(_app_root(); quiet = true)
    exe === nothing && (exe = _find_app_exe(install_app()))
    return exe
end

"""Directory containing the MeSCoT executable."""
app_dir() = dirname(app_exe())

"""
    example_dir(name = "GxG") -> String

Path of one of the demonstration examples bundled with the MeSCoT
application (`"GxG"` or `"GxE"`), containing `data/`, `param/` and a
`run_example.sh` launcher.
"""
function example_dir(name::AbstractString = "GxG")
    app_exe()  # ensure the application is installed
    want = "example_" * name
    for (d, dirs, files) in walkdir(_app_root())
        for dd in dirs
            lowercase(dd) == lowercase(want) && return joinpath(d, dd)
        end
    end
    error("Example $(name) not found in the MeSCoT installation at $(_app_root())")
end

"""
    uninstall_app()

Remove the MeSCoT application (and the downloaded archive) from the package
scratch space. The MATLAB Runtime is managed by MatlabRuntime_jll and is not
touched.
"""
function uninstall_app()
    rm(_app_root(); recursive = true, force = true)
    rm(_archive(); force = true)
    @info "Removed the MeSCoT application from $(_app_root())"
    return nothing
end

