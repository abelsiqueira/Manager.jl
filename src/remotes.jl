function set_origin_and_org_remotes(
  org::String = "JuliaSmoothOptimizers", # github.com/org/...
  orgremotename::String = "org", # git remote rename origin org ...
  user::String = "abelsiqueira"; # git remote add origin .../abelsiqueira/...
  all_repos = repos(org)[1],
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
