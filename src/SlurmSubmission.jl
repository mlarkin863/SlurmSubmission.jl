module SlurmSubmission

struct ClusterInfo
    cores_per_node::Int
    mem_per_cpu::Int
    account::String
    partition::String
end


get_default_account() = read(`sacctmgr show user $USER format=DefaultAccount -nP`, String)

const SulisCluster = ClusterInfo(128, 3850, "su007-rjm", "compute")
const AvonCluster = ClusterInfo(48, 3700, "chemistryrjm", "compute")
const OracCluster = ClusterInfo(28, 4571, "chemistryrjm", "cnode")

function ClusterInfo() 
    machine = read(`hostname`, String)
    if machine == "login01.sulis.hpc\n"
        return SulisCluster
    elseif machine == "login01.avon.hpc\n"
        return AvonCluster
    elseif machine == "login1.orac.cluster\n"
        return OracCluster
    else
        throw(error("Cluster not recognised."))
    end
end

struct Options
    script_name::String
    sbatch_options::Vector{String}
    julia_script::String
end

function Options(julia_script; kwargs...)
    sbatch_options = get_sbatch_options(;kwargs...)
    Options("submit.sh", sbatch_options, julia_script)
end

function get_sbatch_options(;time::String, nodes::Int, partition=nothing, account=nothing)

    cluster = ClusterInfo()

    (partition === nothing) && (partition = cluster.partition)
    (account === nothing) && (account = cluster.account)

    return [
        "--time=$time"
        "--nodes=$nodes"
        "--ntasks-per-node=$(cluster.cores_per_node)"
        "--cpus-per-task=1"
        "--mem-per-cpu=$(cluster.mem_per_cpu)"
        "--account=$(account)"
        "--partition=$(partition)"
    ]
end

function write_script(options::Options, parameter_file)
    open(options.script_name, "w") do io
        println(io, "#!/bin/bash")
        for line in options.sbatch_options
            println(io, "#SBATCH $line")
        end
        julia_path = joinpath(Sys.BINDIR, "julia")
        println(io, join([julia_path, options.julia_script, parameter_file], " "))
    end
end

function submit_script(options::Options)
    run(`sbatch $(options.script_name)`)
    run(`rm $(options.script_name)`)
end

end
