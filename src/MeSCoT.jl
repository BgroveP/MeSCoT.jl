module MeSCoT

using Scratch
using MatlabRuntime_jll

export
    # Application (download / install)
    install_app, uninstall_app, is_app_installed, app_dir, app_exe, example_dir,
    # MATLAB Runtime resolution
    runtime_root, runtime_version_dir,
    # Simulation set-up
    MeSCoTConfig, ModelParameters, write_tsim, write_grm, parse_tsim,
    # Input data files
    SnpData, CoreSnpData, GeneNetwork,
    read_snp_data, write_snp_data, read_core_data, write_core_data,
    read_network, write_network,
    # Running simulations
    run_mescot, simulate,
    # Results
    MeSCoTResult, GeneData, result_dir,
    read_traits, read_ref_trait, read_time, read_gene_data,
    read_rna, read_p, read_products,
    # Constants
    MESCOT_URL, MESCOT_RUNTIME_RELEASE

# --------------------------------------------------------------------------------
# Constants
# --------------------------------------------------------------------------------

"""MATLAB release MeSCoT was compiled with (MATLAB Compiler R2017a).
The executable only runs against this exact runtime version (9.2, folder `v92`)."""
const MESCOT_RUNTIME_RELEASE = "R2017a"

"""Download page of the MeSCoT software (Aarhus University)."""
const MESCOT_URL_BASE = "https://genetics.ghpc.au.dk/vimi/mescot/downloads"

"""URL of the MeSCoT application archive for the current platform (~68 MiB)."""
const MESCOT_URL =
    Sys.iswindows() ? "$(MESCOT_URL_BASE)/mescot_win64.zip" :
    Sys.islinux()    ? "$(MESCOT_URL_BASE)/mescot_lin64.zip" :
    error("MeSCoT provides binaries only for Windows x64 and Linux x64")

const MARKER = ".mescot_jl"
const _PATHSEP = Sys.iswindows() ? ';' : ':'

"""MathWorks platform identifier (win64 / glnxa64); validates the platform."""
function _platform()
    if Sys.iswindows()
        Sys.ARCH === :x86_64 && return "win64"
        error("MeSCoT supports only 64-bit Windows.")
    elseif Sys.islinux()
        Sys.ARCH === :x86_64 && return "glnxa64"
        error("MeSCoT supports only 64-bit Linux (x86_64).")
    end
    error("MeSCoT supports only Windows x64 and Linux x64; " *
          "macOS is not supported by the MeSCoT software.")
end


include("app.jl")
include("runtime.jl")
include("config.jl")
include("datafiles.jl")
include("run.jl")
include("results.jl")

end # module
