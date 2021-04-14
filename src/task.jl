
function task_branch_commit_and_pr(
  myrepo;
  org::String = "JuliaSmoothOptimizers",
  task = fix_travis,
  user = "abelsiqueira",
  commit_msg = "Update travis with latest Julia",
)
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

function task_branch_commit_and_pr_in_all_repos(
  org::String = "JuliaSmoothOptimizers";
  task = fix_travis,
  user = "abelsiqueira",
  commit_msg = "Update travis with latest Julia",
  all_repos = repos(org)[1],
)
  for r in all_repos
    if r.name[(end - 2):end] != ".jl"
      continue
    end
    try
      task_branch_commit_and_pr(r, org = org, task = task, user = user, commit_msg = commit_msg)
    catch e
      @error("ERROR: Could not finish task", e)
    end
  end
end
