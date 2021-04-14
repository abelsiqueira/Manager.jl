module Manager

using Git, GitHub, YAML

const stable_versions = ["1.0", "1.1", "1.2"]

include("branch.jl")
include("clone.jl")
include("remotes.jl")
include("task.jl")
include("travis.jl")

end # module
