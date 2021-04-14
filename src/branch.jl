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
  pr_params = Dict(
    :title => commit_msg,
    :head => "$user:$branch_name",
    :base => "master",
    :maintainer_can_modify => true,
    :draft => false,
    :body => ":robot: This pull request is brought to you by JSO",
  )
  mypr = create_pull_request(api, myrepo, auth = myauth, params = pr_params)
  @info "created pull request" mypr.url
end
