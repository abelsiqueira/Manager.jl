"""
    fix_travis(dir = "")

Read `joinpath(dir, ".travis.yml")` and add the current julia stable versions.
Returns `true` if modifications were made (and thus a commit is necessary) and
`false` if either all stable versions are being tested or the package is not
testing in any stable version because it believes it's inactive. If the folder
is dirty, the modification is not made and `false` is returned.
"""
function fix_travis(dir = "")
  f = joinpath(dir, ".travis.yml")
  if !isfile(f)
    @error("$f not a file")
  end
  if read(`git diff --stat`, String) != ""
    @warn("Working directory is not clean. Not modifying travis.")
    return false
  end
  yaml = YAML.load_file(f)
  julia_versions = string.(yaml["julia"])
  if all(match.(r"^1", julia_versions) .== nothing) # No current Julia version
    @warn("Project doesn't test with any stable Julia version. Not fixing.")
    return false
  end

  new_julia_versions = sort(julia_versions ∪ stable_versions)
  if julia_versions == new_julia_versions
    @info("Package is already testing with all stable versions")
    return false
  end
  julia_versions = new_julia_versions

  # Start rewriting the file
  lines = readlines(f)
  flag_in_version = false
  output = String[]
  for line in lines
    if flag_in_version
      if length(line) > 0 && line[1:3] == "  -"
        continue
      else
        flag_in_version = false
      end
    end
    push!(output, line)
    if line == "julia:"
      flag_in_version = true
      for j in julia_versions
        push!(output, "  - $j")
      end
    end
  end

  open(f, "w") do io
    write(io, join(output, "\n") * "\n")
  end
  return true
end
