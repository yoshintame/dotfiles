alias gd="git diff"
alias gdc="git diff --cached"
alias gcl='git clone'
alias ga='git add'
alias gall='git add .'
alias g='git'
alias gs='git status'
alias gss='git status -s'
alias gl='git pull'
alias gpr='git pull --rebase'
alias gpp='git pull && git push'
alias gup='git fetch && git rebase'
alias gp='git push'
alias gpf='git push --force'
alias gpo='git push origin'
alias gdv='git diff -w "$@" | vim -R -'
alias gc='git commit -v'
alias gca='git commit --amend'
alias gcan='git commit --amend --no-edit'
alias gcm="git commit -v -m"
alias gsh="git show"
alias gb='git branch'
alias gcp='git cherry-pick'
alias gco='git checkout'
alias gcob='git checkout -b'
alias gll='git log --graph --pretty=oneline --abbrev-commit'
alias gg="git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr)%Creset' --abbrev-commit --date=relative"
alias gcapf="ga . && gca --no-edit && gp -f"
alias gt="cd 'git rev-parse --show-toplevel'"
gpuo() {
    git push -u origin $(git rev-parse --abbrev-ref HEAD)
}

alias fetchout='git fetch origin master-passing-tests && git checkout -B master origin/master-passing-tests && git checkout'
alias fetcherge='git fetch origin master-passing-tests && git merge origin/master-passing-tests --no-edit'

alias gch='git branch -v --sort=-committerdate | fzf --layout=reverse-list --bind "enter:execute(git checkout {1})+accept-non-empty"'

alias grb='git branch -v --sort=-committerdate | fzf --layout=reverse-list --bind "enter:execute(git rebase {1})+accept-non-empty"'

gwa() {
    local worktree_name
    local branch_name
    branch_name="$1"
    worktree_name=$(echo "$1" | sed 's/\//-/g')

    git worktree add "$worktree_name" -b "$branch_name"
}