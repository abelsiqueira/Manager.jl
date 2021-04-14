function clone_repos(org::String = "JuliaSmoothOptimizers"; repo_list = repos(org)[1])
  for r in repo_list
    name, url = r.name, r.html_url
    if isdir(name)
      println("$name is already downloaded")
      continue
    end
    println("Cloning $name")
    run(`git clone $url`)
  end
end
