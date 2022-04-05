
struct ClusterInfo
    name::String
    options::Dict{Symbol,Any}
end

get_default_account() = read(`sacctmgr show user $USER format=DefaultAccount -nP`, String)

const SulisCluster = ClusterInfo("sulis",
    Dict{Symbol,Any}(
        :ntasks_per_node=>128,
        :mem_per_cpu=>3850,
        :account=>"su007-rjm",
        :partition=>"compute",
        :cpus_per_task=>1
    )
)
const AvonCluster = ClusterInfo("avon",
    Dict{Symbol,Any}(
        :ntasks_per_node=>48,
        :mem_per_cpu=>3700,
        :account=>"chemistryrjm",
        :partition=>"compute",
        :cpus_per_task=>1
    )
)
const OracCluster = ClusterInfo("orac",
    Dict{Symbol,Any}(
        :ntasks_per_node=>28,
        :mem_per_cpu=>4571,
        :account=>"chemistryrjm",
        :partition=>"cnode",
        :cpus_per_task=>1
    )
)
const ArcherCluster = ClusterInfo("archer",
    Dict{Symbol,Any}(
        :ntasks_per_node=>128,
        :account=>"E635",
        :partition=>"standard",
        :cpus_per_task=>1,
        :qos=>"standard"
    )
)

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
