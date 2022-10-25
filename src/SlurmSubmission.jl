module SlurmSubmission

export DistributedOptions
export SplitThreadsOptions
export SerialOptions

export write_script
export submit_script
export remove_script

using Term

include("clusters.jl")

struct Options
    cluster::ClusterInfo
    sbatch_options::Dict{Symbol,Any}
    extra::String
end

function Base.show(io::IO, options::Options)
    buffer = IOBuffer()
    print_sbatch_info(buffer, options)
    sbatchstring = chomp(String(take!(buffer)))

    sbatch_panel = Panel(
        subtitle="{bold cyan}Cluster: {green italic}`$(options.cluster.name)`",
        subtitle_justify=:right,
        sbatchstring;
        style="bold cyan",
        fit=true,
    )

    buffer = IOBuffer()
    print_extra(buffer, options)
    extrastring = chomp(String(take!(buffer)))

    extra_panel = Panel(
        extrastring;
        title="Additional info",
        style="bold green",
        fit=true
    )

    options_panel = Panel(
        sbatch_panel * extra_panel,
        title="Submission options",
        style="bold gold1",
        fit=true
    )

    print(io,
        options_panel
    )
end

function DistributedOptions(extra=""; kwargs...)
    cluster = ClusterInfo()
    sbatch_options = generate_sbatch_options(cluster, kwargs)
    options = Options(cluster, sbatch_options, extra)
    print(options)
    return options
end

function SerialOptions(extra=""; kwargs...)
    cluster = ClusterInfo()
    sbatch_options = generate_sbatch_options(cluster, kwargs)
    sbatch_options[:cpus_per_task] = 1
    sbatch_options[:ntasks_per_node] = 1

    options = Options(cluster, sbatch_options, extra)
    print(options)
    return options
end

function SplitThreadsOptions(;kwargs...)
    cluster = ClusterInfo()
    sbatch_options = generate_sbatch_options(cluster, kwargs)
    sbatch_options[:cpus_per_task] = sbatch_options[:ntasks_per_node]
    sbatch_options[:ntasks_per_node] = 1

    options = Options(cluster, sbatch_options, extra)
    print(options)
    return options
end

function generate_sbatch_options(cluster, kwargs)
    sbatch_options = Dict{Symbol,Any}(kwargs)
    for (key, value) in cluster.options
        if !haskey(sbatch_options, key)
            sbatch_options[key] = value
        end
    end
    return sbatch_options
end

function print_sbatch_info(io, options::Options)
    for (key, value) in options.sbatch_options
        keyword = replace(string(key), "_"=>"-")
        println(io, "#SBATCH --$keyword=$value")
    end
end

function print_extra(io, options::Options)
    println(io, "export JULIA_DEPOT_PATH=\"$(DEPOT_PATH[1])\"")
    println(io, "export OMP_NUM_THREADS=1")
    println(io, options.extra)
end

function write_script(options::Options, args...)
    open("sh.sh", "w") do io
        println(io, "#!/bin/bash")
        print_sbatch_info(io, options)
        print_extra(io, options)
        print_julia_command(io, args...)
    end
end

function print_julia_command(io, args...)
    julia_path = joinpath(Sys.BINDIR, "julia")
    join(io, [julia_path, args...], " ")
end

submit_script() = run(`sbatch sh.sh`)
remove_script() = run(`rm sh.sh`)

end
