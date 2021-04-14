export clone_repos

"""
    clone_repos(repo_list; workdir = "workdir", exclude_non_julia = true)

Clone the repos given by `repo_list` to the folder `workdir`.
A possible value for `repo_list` is `GitHub.repos(org)[1]`.
If `exclude_non_julia`, then if the language of the repo is not Julia, does not clone.
Useful to avoid sites, for instance.
"""
function clone_repos(repo_list; workdir = "workdir", exclude_non_julia = true)
  isdir(workdir) || mkdir(workdir)
  cd(workdir) do
    for r in repo_list
      name, url = r.name, r.html_url
      if exclude_non_julia && r.language != "Julia"
        @warn "Ignoring $name because it's language is not Julia"
        continue
      end
      if isdir(name)
        @warn "$name is already downloaded"
        continue
      end
      @info "Cloning $name"
      run(`git clone $url`)
    end
  end
end
