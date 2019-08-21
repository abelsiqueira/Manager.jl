module Manager

using GitHub, YAML

export clone_repos, fix_travis, set_origin_and_org_remotes

const stable_versions = ["1.0", "1.1", "1.2"]

function clone_repos(org :: String = "JuliaSmoothOptimizers"; all_repos = repos(org)[1])
  for r in all_repos
    name, url = r.name, r.html_url
    if isdir(name)
      println("$name is already downloaded")
      continue
    end
    println("Cloning $name")
    run(`git clone $url`)
  end
end

function set_origin_and_org_remotes(org :: String = "JuliaSmoothOptimizers", # github.com/org/...
                                    orgremotename :: String = "org", # git remote rename origin org ...
                                    user :: String = "abelsiqueira"; # git remote add origin .../abelsiqueira/...
                                    all_repos = repos(org)[1]
                                   )
  for r in all_repos
    name, url = r.name, string(r.html_url)
    originurl = replace(url, "$org/$name" => "$user/$name")
    if !isdir(name)
      @error("$name is not downloaded. Check `clone_repos`")
    end
    cd(name)
    remotes = split(read(`git remote`, String))
    if orgremotename in remotes
      @info("$name already has remote $orgremotename. Skipping")
      cd("..")
      continue
    end
    run(`git remote rename origin $orgremotename`)
    run(`git remote add origin $originurl`)
    cd("..")
  end
end

"""
    fix_travis(dir = "")

Read `joinpath(dir, ".travis.yml")` and add the current julia stable versions.
Returns `true` if modifications were made (and thus a commit is necessary) and
`false` if either all stable versions are being tested or the package is not
testing in any stable version because it believes it's inactive.
"""
function fix_travis(dir = "")
  f = joinpath(dir, ".travis.yml")
  if !isfile(f)
    @error("$f not a file")
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

  # Start rewriting the file
  lines = readlines(f)
  flag_in_version = false
  output = String[]
  for line in lines
    if flag_in_version
      if length(line) > 0 && line[1:2] == "  "
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

end # module
