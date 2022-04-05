module SlurmSubmission

export DistributedOptions
export SplitThreadsOptions

export write_script
export submit_script
export remove_script

using Term

include("clusters.jl")

struct Options
    cluster::ClusterInfo
    sbatch_options::Dict{Symbol,Any}
    mode::Symbol
end

function Base.show(io::IO, options::Options)
    buffer = IOBuffer()
    print_sbatch_info(buffer, options)
    sbatchstring = String(take!(buffer))

    sbatch_panel = Panel(
        sbatchstring;
        style="bold cyan",
        fit=true,
    )
    options_panel = Panel(
        Spacer(1,1),
        RenderableText("[bold cyan]Cluster: [green italic]`$(options.cluster.name)`"),
        Spacer(1,1),
        sbatch_panel,
        title="Submission options",
        style="gold1 bold",
        fit=true
    )
    print(io,
        options_panel
    )
end

function DistributedOptions(;kwargs...)
    cluster = ClusterInfo()
    sbatch_options = generate_sbatch_options(cluster, kwargs)
    options = Options(cluster, sbatch_options, :Distributed)
    print(options)
    return options
end

function SplitThreadsOptions(;kwargs...)
    cluster = ClusterInfo()
    sbatch_options = generate_sbatch_options(cluster, kwargs)
    sbatch_options[:cpus_per_task] = sbatch_options[:ntasks_per_node]
    sbatch_options[:ntasks_per_node] = 1

    options = Options(cluster, sbatch_options, :SplitThreads)
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

function write_script(options::Options, args...)
    open("sh.sh", "w") do io
        println(io, "#!/bin/bash")
        print_sbatch_info(io, options)
        println(io, "export JULIA_DEPOT_PATH=\"$(DEPOT_PATH[1])\"")
        println(io, "export OMP_NUM_THREADS=1")
        print_julia_command(io, options, args...)
    end
end

function print_julia_command(io, options::Options, args...)
    if options.mode == :Distributed
        processes = options.sbatch_options[:nodes] * options.sbatch_options[:ntasks_per_node]
    elseif options.mode == :SplitThreads
        processes = options.sbatch_options[:nodes]
    end
    threads = options.sbatch_options[:cpus_per_task]
    julia_path = joinpath(Sys.BINDIR, "julia")
    join(io, [julia_path, args...], " ")
end

submit_script() = run(`sbatch sh.sh`)
remove_script() = run(`rm sh.sh`)

end
