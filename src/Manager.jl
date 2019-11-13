module Manager

using Git, GitHub, YAML

export branch_and_pr, clone_repos, fix_travis, set_origin_and_org_remotes,
       task_branch_commit_and_pr, task_branch_commit_and_pr_in_all_repos,
       look_for_rebased_and_merged_branchs

const stable_versions = ["1.0", "1.1", "1.2"]

# TODO: Create a file for tasks

function branch_and_pr(branch_name, commit_msg, myrepo, user)
  current_branch = Git.branch()
  current_branch == "master" || error("only PRs off of master are supported for now")

  Git.staged() && error("repository already contains staged files")

  updated_files = split(Git.readchomp(`diff --name-only`), '\n')
  length(updated_files) > 0 || error("no modified files in repository")
  @info "files to commit" updated_files

  Git.run(`checkout -b $branch_name`)
  for updated_file ∈ updated_files
    Git.run(`add $updated_file`)
  end
  Git.run(`commit -m $commit_msg`)
  Git.run(`push -u origin $branch_name`)
  Git.run(`checkout master`)

  # your GitHub.jl personal access token must have "public_repo" access enabled
  myauth = GitHub.authenticate(ENV["GITHUB_AUTH"])

  api = GitHub.DEFAULT_API
  pr_params = Dict(:title => commit_msg,
                   :head => "$user:$branch_name",
                   :base => "master",
                   :maintainer_can_modify => true,
                   :draft => false,
                   :body => ":robot: This pull request is brought to you by JSO")
  mypr = create_pull_request(api, myrepo, auth=myauth, params=pr_params)
  @info "created pull request" mypr.url
end

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

function task_branch_commit_and_pr(myrepo; org :: String = "JuliaSmoothOptimizers",
                                   task = fix_travis,
                                   user = "abelsiqueira",
                                   commit_msg = "Update travis with latest Julia")
  name, url = myrepo.name, myrepo.html_url
  if !isdir(name)
    @error("$name is not downloaded. Check `clone_repos`")
  end

  cd(name)
  try
    @info("Appling $task on $name")
    modified = task() # Perform task
    if !modified
      @info("Task $task did not make any modifications.")
      return false
    end
    @info("Branching and commiting")
    myrepo = repo("$org/$name")
    branch_and_pr(string(task), commit_msg, repo("$org/$name"), user)
  finally
    cd("..")
  end
  return true
end

function task_branch_commit_and_pr_in_all_repos(org :: String = "JuliaSmoothOptimizers";
                                                task = fix_travis,
                                                user = "abelsiqueira",
                                                commit_msg = "Update travis with latest Julia",
                                                all_repos = repos(org)[1])
  for r in all_repos
    if r.name[end-2:end] != ".jl"
      continue
    end
    try
      task_branch_commit_and_pr(r, org=org, task=task, user=user, commit_msg=commit_msg)
    catch e
      @error("ERROR: Could not finish task", e)
    end
  end
end

function look_for_rebased_and_merged_branchs()
  commit_hashes = readlines(`git log --format="%h" master`)
  commit_tree_hashes = readlines(`git log --format="%t" master`)
  commit_titles = readlines(`git log --format="%s" master`)
  branches = strip.(readlines(`git branch`))

  for br in branches
    occursin("master", br) && continue
    occursin("gh-pages", br) && continue
    println(greenstr("Branch $br"))

    brhash  = chomp(read(`git log -1 --format="%h" $br`, String))
    brtree  = chomp(read(`git log -1 --format="%t" $br`, String))
    brtitle = chomp(read(`git log -1 --format="%s" $br`, String))
    found = false
    if brhash in commit_hashes
      println_maxwidth("  Commit $brhash ($brtitle) appears to be fully integrated into master")
      found = true
    elseif brtree in commit_tree_hashes
      println_maxwidth("  Commit $brhash ($brtitle) appears integrated through a rebase because it's tree hash is the same")
      i = findfirst(brtree .== commit_tree_hashes)
      if brtitle != commit_titles[i]
        println("  HOWEVER, the titles are not the same:")
        println("    master: $(commit_titles[i])")
        println("    $br: $brtitle")
      end
      found = true
    elseif brtitle in commit_titles
      println("  Commit with same title found in master:")
      i = findfirst(brtitle .== commit_titles)
      println("    title: $brtitle")
      println("    master: $(commit_hashes[i])")
      println("    $br: $brhash")
      found = true
    end
  end
end

function println_maxwidth(s; maxwidth=80, allow=10)
  if length(s) < maxwidth + allow
    println(s)
  else
    space = match(r"^\s*", s).match
    out = []
    ss = split(s)
    while length(join(out, " ")) + length(ss[1]) < maxwidth
      push!(out, popfirst!(ss))
    end
    println(space * join(out, " "))
    println_maxwidth(space * join(ss, " "), maxwidth=maxwidth, allow=allow)
  end
end

redstr(s)    = "\033[1;31m$s\033[0m"
greenstr(s)  = "\033[1;32m$s\033[0m"
yellowstr(s) = "\033[1;33m$s\033[0m"

end # module
