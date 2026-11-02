# MeSCoT.jl

A Julia interface to [MeSCoT](https://genetics.ghpc.au.dk/vimi/mescot/) —
*Mechanistic Simulation of Complex Traits*, the Aarhus University software
for mechanistic simulation of gene-by-gene (GxG) and gene-by-environment (GxE)
interactions underlying quantitative traits.

MeSCoT ships as a stand-alone application compiled with MATLAB Compiler
(R2017a). This package

- downloads and installs the MeSCoT application into the package scratch space,
- resolves the MATLAB Runtime R2017a (`v92`) the binary requires, through
  [MatlabRuntime_jl](https://github.com/BgroveP/MatlabRuntime.jl),
- writes MeSCoT interface files (`*.tsim` configuration, `*.grm` model
  parameters, `*.dat` SNP data) from Julia data structures,
- runs the simulation and parses the output files
  (`traits.txt`, `rna.txt`, `p.txt`, `products.txt`, `time.txt`, `*.gntw`)
  into Julia arrays.

Supported platforms: **Windows x64** and **Linux x64** (as the MeSCoT
binaries; macOS is not supported).

## Installation

```julia
using Pkg
Pkg.add(url = "https://github.com/BgroveP/MatlabRuntime.jl")  # MATLAB Runtime provider
Pkg.add(url = "<this repository>")                            # MeSCoT.jl
```

## The MATLAB Runtime requirement

The MeSCoT executable is locked to the exact runtime version it was compiled
with: **MATLAB Runtime R2017a, version 9.2, folder `v92`**. MathWorks no
longer distributes runtimes that old (installer downloads stop at R2019a, the
container registry at R2021b), so it cannot be fetched automatically.

Point the wrapper at an existing R2017a runtime installation, in this order:

1. `runtime_root(root = "...")` argument,
2. environment variable `MESCOT_RUNTIME_ROOT`,
3. `MATLABRUNTIME_JLL_ROOT` / `MCR_ROOT`, or a standard location
   (`/usr/local/MATLAB/MATLAB_Runtime`, `/opt/...` on Linux,
   `%ProgramFiles%\MATLAB\MATLAB Runtime` on Windows) — accepted only if the
   tree actually contains `v92`,
4. a `MatlabRuntime_jll`-managed installation, if you placed one there.

The root is the directory *containing* the `v92` folder (passing the `v92`
folder itself also works and is normalized).

## Usage

```julia
using MeSCoT

# Simulation set-up (keywords mirror the *.tsim file; defaults follow the docs)
sim = MeSCoTConfig(snp = "data/rand_allele.dat",    # $SNP   allele data (mandatory)
                   core = "data/rand_core.dat",     # $CORE  core SNPs   (mandatory)
                   outres = "GxG_results",         # $OUTRES results folder
                   rng = 886246581)                 # $RNG

# Model parameters (keywords mirror the *.grm file)
model = ModelParameters(n1 = 1.0, beta1 = 0.02, mode = "mix", ratio = 0.7,
                        snpdiff = 0.25)

# Write interface files, run MeSCoT (downloads the app on first use)
result = simulate(sim, model; dir = "my_study")

# Parse outputs
traits = read_traits(result)        # (id, value): genomic (trait) values per genotype
rna    = read_rna(result; genotype = 1)   # GeneData: mRNA time series of all genes
proteins = read_p(result; genotype = 1)  # GeneData: protein time series of all genes
products = read_products(result)         # GeneData: core gene products
times  = read_time(result)          # time points of the dynamic solution
```

With full output, MeSCoT writes the results under the `\$OUTRES` folder:
`traits.txt`, `products_<range>.txt`, the saved network geometry
(`N/A/R_snpID.gntw`), the reference genotype results (`ref_trait.txt`,
`ref_products.txt`) and one folder per simulated genotype containing
`rna.txt`, `p.txt` and `time.txt`. The readers above locate and parse these.

Note that MeSCoT **appends** to files in an existing `\$OUTRES` folder on
re-run; use a fresh `outres` (or remove the folder) when re-simulating.

Running an existing `*.tsim` file directly:

```julia
result = run_mescot("study.tsim"; dir = "my_study")
```

Interface-file utilities:

```julia
write_tsim(sim, "study.tsim")       # write a configuration file
write_grm(model, "model.grm")       # write a model parameters file
parse_tsim("study.tsim")            # keyword => value dictionary
read_snp_data("rand_allele.dat")    # SnpData(id, chip, alleles)
read_core_data("rand_core.dat")     # CoreSnpData(snp, weight)
read_network("N_snpID.gntw")        # GeneNetwork(from, to, weight)
```

## API

| Function | Description |
| --- | --- |
| `install_app(; force, keep_archive)` | Download + extract the MeSCoT application (~68 MiB) into the package scratch space. |
| `uninstall_app()` | Remove the MeSCoT application and archive. |
| `is_app_installed()`, `app_dir()`, `app_exe()` | Application state and locations. |
| `example_dir(name)` | Bundled demonstration examples (`"GxG"`, `"GxE"`). |
| `runtime_root(; root, release)` | Resolve the MATLAB Runtime root (`v92` parent); see above. |
| `runtime_version_dir(; root)` | The runtime version directory (`.../v92`), as the official launchers' `<mcr_directory>`. |
| `MeSCoTConfig(; kwargs...)`, `write_tsim`, `parse_tsim` | Simulation configuration (`*.tsim`). |
| `ModelParameters(; kwargs...)`, `write_grm` | Model parameters (`*.grm`). |
| `SnpData`, `CoreSnpData`, `GeneNetwork` + readers/writers | Input data files. |
| `run_mescot(config; dir, root, release)` | Run MeSCoT on a `*.tsim` file (or a `MeSCoTConfig`). |
| `simulate(config, model; dir, root)` | Write the interface files and run the simulation. |
| `read_traits`, `read_ref_trait`, `read_rna`, `read_p`, `read_products`, `read_time` | Output readers (`read_rna`/`read_p`/`read_time` take `genotype` for per-genotype files). |

## Testing

```bash
julia --project=. -e 'using Pkg; Pkg.test()'                        # unit tests
MESCOT_TEST_INSTALL=1 julia --project=. -e 'using Pkg; Pkg.test()'   # + app download/install
MESCOT_TEST_RUN=1     julia --project=. -e 'using Pkg; Pkg.test()'   # + end-to-end GxG example
```

The end-to-end test is skipped unless a MATLAB Runtime R2017a (`v92`) is
reachable via the resolution order above.

## References

- MeSCoT software, V. Milkevych, Aarhus University (2020):
  <https://genetics.ghpc.au.dk/vimi/mescot/>
- Boyle, Li & Pritchard (2017), *An Expanded View of Complex Traits: From
  Polygenic to Omnigenic*, Cell 169(7) — the omnigenic model MeSCoT implements.
- MATLAB Runtime: <https://www.mathworks.com/products/compiler/matlab-runtime.html>
