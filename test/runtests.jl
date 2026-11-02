using Test
using MeSCoT
using MatlabRuntime_jll

_flag(key) = try
    parse(Bool, lowercase(get(ENV, key, "false")))
catch
    false
end

@testset "MeSCoT.jl" begin

    @testset "platform and URLs" begin
        @test MeSCoT.MESCOT_RUNTIME_RELEASE == "R2017a"
        @test startswith(MeSCoT.MESCOT_URL,
                         "https://genetics.ghpc.au.dk/vimi/mescot/downloads/mescot_")
        @test occursin(Sys.iswindows() ? "win64" : "lin64", MeSCoT.MESCOT_URL)
    end

    @testset "config and model parameter files" begin
        mktempdir() do d
            cfg = MeSCoTConfig(snp = "data/rand_allele.dat",
                               core = "data/rand_core.dat",
                               modelpar = "param/model.grm",
                               outres = "GxG_results", rng = 886246581)
            f = joinpath(d, "study.tsim")
            write_tsim(cfg, f)
            txt = read(f, String)
            @test occursin("\$SNP\ndata/rand_allele.dat", txt)
            @test occursin("\$CORE\ndata/rand_core.dat", txt)
            @test occursin("\$MODELPAR\nparam/model.grm", txt)
            @test occursin("\$OUTRES\nGxG_results", txt)
            @test occursin("\$ALL\n1", txt)
            @test occursin("\$REPRODUCE\n0", txt)
            @test !occursin("\$RESULTS", txt)  # full output is the default

            p = parse_tsim(f)
            @test p["SNP"] == "data/rand_allele.dat"
            @test p["MODELPAR"] == "param/model.grm"
            @test p["OUTRES"] == "GxG_results"
            @test p["RNG"] == "886246581"

            # limited results mode adds $RESULTS
            cfg2 = MeSCoTConfig(cfg; results = "limited")
            f2 = joinpath(d, "limited.tsim")
            write_tsim(cfg2, f2)
            @test occursin("\$RESULTS\nlimited", read(f2, String))

            # validation
            @test_throws ErrorException write_tsim(MeSCoTConfig(), f2)
            @test_throws ErrorException MeSCoT.write_tsim(
                MeSCoTConfig(snp = "a", core = "b", results = "bogus"), f2)

            m = ModelParameters(mode = "mix", ratio = 0.7, n1 = 1.0,
                                beta1 = 0.02, gendiff = 0.3, snpdiff = 0.25)
            g = joinpath(d, "model.grm")
            write_grm(m, g)
            txt = read(g, String)
            @test occursin("\$ARCH\ndownstream", txt)
            @test occursin("\$MODE\nmix", txt)
            @test occursin("\$RATIO\n0.7", txt)
            @test occursin("\$GENDIFF\n0.3", txt)
            @test occursin("\$RATEP\n8.0", txt)
            @test occursin("\$KACT\n500000.0", txt)

            pm = parse_tsim(g)
            @test pm["MODE"] == "mix"
            @test pm["RATERNA"] == "4.0"
            @test pm["SNPDIFF"] == "0.25"
        end
    end

    @testset "input data files" begin
        mktempdir() do d
            snp = SnpData([1, 2, 3], [2, 4, 6], [1 2 0; 0 1 1; 2 2 2])
            f = joinpath(d, "rand_allele.dat")
            write_snp_data(snp, f)
            @test read(joinpath(d, "rand_allele.dat"), String) ==
                  "1 2 1 2 0\n2 4 0 1 1\n3 6 2 2 2\n"
            back = read_snp_data(f)
            @test back.id == [1, 2, 3]
            @test back.chip == [2, 4, 6]
            @test back.alleles == [1 2 0; 0 1 1; 2 2 2]

            core = CoreSnpData([2, 4], [1.0, 1.0])
            cf = joinpath(d, "rand_core.dat")
            write_core_data(core, cf)
            back = read_core_data(cf)
            @test back.snp == [2, 4]
            @test back.weight == [1.0, 1.0]

            net = GeneNetwork([1, 15], [2, 2], [1.0, 1.0])
            nf = joinpath(d, "N_snpID.gntw")
            write_network(net, nf)
            back = read_network(nf)
            @test back.from == [1, 15]
            @test back.to == [2, 2]
            @test back.weight == [1.0, 1.0]
        end
    end

    @testset "output readers" begin
        mktempdir() do d
            write(joinpath(d, "traits.txt"), "1 0.5\n2 -1.25\n3 10\n")
            t = read_traits(joinpath(d, "traits.txt"))
            @test t.id == [1, 2, 3]
            @test t.value == [0.5, -1.25, 10.0]

            # time.txt is one line of space-separated time points
            write(joinpath(d, "time.txt"), "0 0.25 0.5\n")
            @test read_time(joinpath(d, "time.txt")) == [0.0, 0.25, 0.5]

            # full-output layout: per-genotype folders with rna.txt/p.txt
            mkpath(joinpath(d, "1"))
            write(joinpath(d, "1", "rna.txt"), "2 1 0.1 0.2 0.3\n4 3 0.4 0.5 0.6\n")
            write(joinpath(d, "1", "p.txt"), "2 1 1.0 1.1 1.2\n")
            write(joinpath(d, "products_1-1.txt"), "2 1 0.07 0.16\n")
            write(joinpath(d, "ref_trait.txt"), "0 387.94\n")
            gd = read_gene_data(joinpath(d, "1", "rna.txt"))
            @test gd.snp == [2, 4]
            @test gd.gene == [1, 3]
            @test gd.values == [0.1 0.2 0.3; 0.4 0.5 0.6]

            # MeSCoTResult-based readers resolve the genotype folders
            res = MeSCoTResult(d, d, joinpath(d, "config.tsim"))
            @test result_dir(res) == d
            @test read_traits(res).value == [0.5, -1.25, 10.0]
            @test read_ref_trait(res).value == [387.94]
            @test read_time(res) == [0.0, 0.25, 0.5]
            @test read_rna(res).values == [0.1 0.2 0.3; 0.4 0.5 0.6]
            @test read_rna(res; genotype = 1).snp == [2, 4]
            @test read_p(res; genotype = 1).values == [1.0 1.1 1.2]
            @test read_products(res).values == reshape([0.07, 0.16], 1, 2)
        end
    end

    @testset "runtime version mapping (R2017a -> v92)" begin
        # public jll mapping the wrapper relies on
        @test MatlabRuntime_jll.release_version("R2017a") == "9.2"
        @test MatlabRuntime_jll.version_dir("R2017a") == "v92"
        # root given as the version directory itself is normalized to its parent
        mktempdir() do d
            fake = joinpath(d, "v92")
            mkpath(joinpath(fake, "runtime"))
            root = MeSCoT._normalize_root(fake; release = "R2017a")
            @test root == d
            # runtime_version_dir prefers the v92 candidate
            @test MeSCoT.runtime_version_dir(; root = d) == fake
        end
        # explicit root wins over everything
        @test runtime_root(; root = "/some/root") == "/some/root"
    end

    _flag("MESCOT_TEST_INSTALL") && @testset "app install (network)" begin
        dir = install_app()
        @test is_app_installed()
        @test isfile(app_exe())
        @test app_dir() == dir
        ex = example_dir("GxG")
        @test isdir(joinpath(ex, "data"))
        @test isfile(joinpath(ex, "param", "GxG_study.tsim"))
        # the shipped example files parse with the keyword parser
        p = parse_tsim(joinpath(ex, "param", "GxG_study.tsim"))
        @test p["SNP"] == "data/rand_allele.dat"
        @test p["CORE"] == "data/rand_core.dat"
        @test p["MODELPAR"] == "param/model.grm"
        @test p["OUTRES"] == "GxG_results"
        pm = parse_tsim(joinpath(ex, "param", "model.grm"))
        @test pm["ARCH"] == "downstream"
        @test pm["MODE"] == "mix"
        # shipped example data files round-trip through the readers
        sd = read_snp_data(joinpath(ex, "data", "rand_allele.dat"))
        @test length(sd.id) == 100
        @test size(sd.alleles, 2) == 50
        cd = read_core_data(joinpath(ex, "data", "rand_core.dat"))
        @test length(cd.snp) == 12
        ntw = read_network(joinpath(example_dir("GxE"), "data", "N_snpID.gntw"))
        @test length(ntw.from) > 0
    end

    _flag("MESCOT_TEST_RUN") && @testset "end-to-end GxG example (runtime)" begin
        runtime_available = try
            runtime_root()
            true
        catch
            false
        end
        if !runtime_available
            @info "Skipping end-to-end test: no MATLAB Runtime R2017a (v92) found; " *
                  "set MESCOT_RUNTIME_ROOT or MATLABRUNTIME_JLL_ROOT."
            @test_skip false
        else
            ex = example_dir("GxG")
            # MeSCoT appends to existing results: start from a clean folder
            rm(joinpath(ex, "GxG_results"); recursive = true, force = true)
            res = run_mescot(joinpath(ex, "param", "GxG_study.tsim"); dir = ex)
            @test isdir(res.outdir)
            @test isfile(joinpath(res.outdir, "traits.txt"))

            # genomic (trait) values for all 100 genotypes
            t = read_traits(res)
            @test length(t.value) == 100
            @test all(isfinite, t.value)

            # per-genotype time series: 50 genes x (time range) values
            time = read_time(res)
            @test length(time) > 1 && time[end] ≈ 500.0
            rna = read_rna(res; genotype = 1)
            @test length(rna.gene) == 50
            @test size(rna.values, 2) == length(time)
            @test all(isfinite, rna.values)
            prot = read_p(res; genotype = 2)
            @test size(prot.values) == size(rna.values)

            # core gene products (12 core SNPs in the example) and network
            prod = read_products(res)
            @test length(prod.gene) == 12
            @test all(isfinite, prod.values)
            @test length(read_network(joinpath(res.outdir, "N.gntw")).from) > 0
        end
    end
end
