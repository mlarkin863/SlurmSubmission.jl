module SlurmSubmission

using Term

struct ClusterInfo
    name::String
    ntasks_per_node::Int
    mem_per_cpu::Int
    account::String
    partition::String
end

get_default_account() = read(`sacctmgr show user $USER format=DefaultAccount -nP`, String)

const SulisCluster = ClusterInfo("sulis", 128, 3850, "su007-rjm", "compute")
const AvonCluster = ClusterInfo("avon", 48, 3700, "chemistryrjm", "compute")
const OracCluster = ClusterInfo("orac", 28, 4571, "chemistryrjm", "cnode")
const ArcherCluster = ClusterInfo("archer", 128, 0, "E635", "standard")

function ClusterInfo() 
    machine = read(`hostname`, String)
    if occursin("sulis", machine)
        return SulisCluster
    elseif occursin("avon", machine)
        return AvonCluster
    elseif occursin("orac", machine)
        return OracCluster
    elseif occursin("ln", machine)
        return ArcherCluster
    else
        throw(error("Cluster not recognised."))
    end
end

struct Options
    cluster::ClusterInfo
    script_name::String
    sbatch_options::Vector{String}
    julia_script::String
end

function Base.show(io::IO, options::Options)
    sbatchstring = join(options.sbatch_options, "\n[green]")

    sbatch_panel = Panel(
        "[green]"*sbatchstring;
        title="#SBATCH",
        style="bold cyan",
        fit=true,
    )
    options_panel = Panel(
        Spacer(1,1),
        RenderableText("[bold cyan]Cluster: [green italic]`$(options.cluster.name)`"),
        RenderableText("[bold cyan]Script name: [green italic]`$(options.julia_script)`"),
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

function Options(julia_script; kwargs...)
    cluster = ClusterInfo()
    sbatch_options = get_sbatch_options(cluster; kwargs...)
    options = Options(cluster, "submit.sh", sbatch_options, julia_script)
    print(options)
    return options
end

function get_sbatch_options(cluster;time::String, nodes=nothing,
    partition=nothing, account=nothing, ntasks_per_node=nothing,
    total_tasks=nothing, job_name="sbatch",
)
    (partition === nothing) && (partition = cluster.partition)
    (account === nothing) && (account = cluster.account)
    (ntasks_per_node === nothing) && (ntasks_per_node = cluster.ntasks_per_node)

    if !(total_tasks === nothing)
        nodes = (total_tasks-1) ÷ cluster.ntasks_per_node + 1
        ntasks_per_node = Int(total_tasks / nodes)
    elseif (nodes === nothing)
        throw(error("You must specify either `nodes` or `total_tasks`."))
    end

    options =  [
        "--time=$time"
        "--nodes=$nodes"
        "--ntasks-per-node=$ntasks_per_node"
        "--cpus-per-task=1"
        "--account=$account"
        "--partition=$partition"
        "--job-name=$job_name"
    ]

    if cluster === ArcherCluster
        push!(options, "--qos=standard")
    else
        push!(options, "--mem-per-cpu=$(cluster.mem_per_cpu)")
    end

    return options
end

function write_script(options::Options, parameter_file)
    open(options.script_name, "w") do io
        println(io, "#!/bin/bash")
        for line in options.sbatch_options
            println(io, "#SBATCH $line")
        end
        println(io, "export JULIA_DEPOT_PATH=\"$(DEPOT_PATH[1])\"")
        println(io, "export OMP_NUM_THREADS=1")
        julia_path = joinpath(Sys.BINDIR, "julia")
        println(io, join([julia_path, options.julia_script, parameter_file], " "))
    end
end

function submit_script(options::Options)
    run(`sbatch $(options.script_name)`)
    run(`rm $(options.script_name)`)
end

function submit_scripts(options, parameter_files; dry_run=false)
    @info "Submitting $(length(parameter_files)) jobs."
    for file in parameter_files
        write_script(options, file)
        dry_run ? @info("Script written but not submitted.") : submit_script(options)
    end
    @info "Success!"
end

end
