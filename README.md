# Manager.jl

Julia Organization Manager. Broken. Untested. Possibly damaging to your repo.

If it's not docummented below, it's because I haven't reviewed it in a long time.

## Usage

**clone** repos from your org.

```julia
julia> org = "MyOrg"
julia> my_repos = GitHub.repos(org)[1]
julia> clone_repos(my_repos)
```