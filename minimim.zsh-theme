# vim: set filetype=zsh :

zmodload zsh/datetime || return

setopt prompt_subst

typeset -g prompt_command_timestamp
typeset -g prompt_command_elapsed

PROMPT='$(build_prompt)'
RPROMPT=''

function build_prompt() {
  echo "$(current_dir) $(shell_status) "
}

function current_dir() {
  echo "%F{green}$(shrink_path -f)%f"
}

function shell_status() {
  echo "%(?.%F{green}%B$%b%f.%F{red}%B$%b%f)"
}

# start timer for prompt
function preexec() {
  prompt_command_timestamp=$EPOCHSECONDS
}

ASYNC_PROC=0
function precmd() {
  local elapsed

  prompt_command_elapsed=

  (( elapsed = EPOCHSECONDS - ${prompt_command_timestamp:-$EPOCHSECONDS} ))

  if (( elapsed > 5 )); then
    prompt_command_elapsed="$(to_human_time $elapsed)"
  fi

  prompt_command_timestamp=

# kill child if still running from previous prompt
if [[ "${ASYNC_PROC}" != 0 ]]; then
  kill -s HUP $ASYNC_PROC >/dev/null 2>&1 || :
fi

# start background computation
async_update_rprompt &!
ASYNC_PROC=$!
}

function build_rprompt() {
  local widgets=()
  if [[ -n "${prompt_command_elapsed}" ]]; then
    widgets+=("${prompt_command_elapsed}")
  fi
  widgets+=($(git_prompt_info) $(version_info))

  echo ${(j: :)widgets}
}

function async_update_rprompt() {
  printf "%s" "$(build_rprompt)" > "${HOME}/.zsh_tmp_prompt"
  kill -s USR1 $$
}

function TRAPUSR1() {
  # read from temp file
  RPROMPT="$(cat ${HOME}/.zsh_tmp_prompt)"

# reset proc number
ASYNC_PROC=0

zle && zle reset-prompt
}

function git_prompt_info() {
  local git_dir=$(git rev-parse --git-dir 2>/dev/null)
  if [[ -d "$git_dir" ]]; then
    local git_stage_info="$(parse_git_stage)"
    local git_info="$(parse_git_branch_or_detached)"
    local git_state_info="$(parse_git_state)"
    echo "%F{yellow}(%f$git_stage_info$git_info$git_state_info%F{yellow})%f"
  fi
}

function parse_git_branch_or_detached() {
  local branch_name=$(git symbolic-ref --short HEAD 2>/dev/null)

  if [[ -z $branch_name ]]; then
    branch_name=$(git describe --tags --exact-match HEAD 2>/dev/null || git rev-parse --short HEAD)
  fi
  echo "%F{yellow}$branch_name%f"
}

function parse_git_stage() {
  local state=""
  [[ -n "$(git ls-files --other --exclude-standard)" ]] && state+="%F{red}-%f"
  [[ -n "$(git diff --stat)" ]] && state+="%F{yellow}-%f"
  [[ -n "$(git diff --cached --stat)" ]] && state+="%F{green}+%f"
  echo "$state"
}

function parse_git_state() {
  local state=""
  local num_ahead=$(git rev-list --count HEAD@{upstream}..HEAD 2>/dev/null)
  local num_behind=$(git rev-list --count HEAD..HEAD@{upstream} 2>/dev/null)
  [[ "$num_ahead" -gt 0 ]] && state+="%F{yellow}+${num_ahead}%f"
  [[ "$num_behind" -gt 0 ]] && state+="%F{yellow}-${num_behind}%f"
  echo "$state"
}

function git_root() {
  git rev-parse --show-toplevel 2>/dev/null
}

# function receives a file path and checks if it is present in the current directory or in git root, params are git_root and file_path
function file_exists() {
  local git_root="$1"
  local file_path="$2"
  [[ -f "$file_path" ]] || [[ -f "$git_root/$file_path" ]]
}

function version_info() {
  local info=()
  local git_root_path="$(git_root)"
  if [[ -n $git_root_path ]]; then
    local versions="$(mise current)"

    file_exists "$git_root_path" "Gemfile" && info+=("%F{red}%B($(echo "$versions" | grep ruby | cut -d ' ' -f2))%b%f")
    file_exists "$git_root_path" "package.json" && info+=("%F{green}%B($(echo "$versions" | grep node | cut -d ' ' -f2))%b%f")
    file_exists "$git_root_path" "mix.exs" && info+=("%F{magenta}%B($(echo "$versions" | grep elixir | cut -d ' ' -f2)/$(echo "$versions" | grep erlang | cut -d ' ' -f2))%b%f")
    file_exists "$git_root_path" "Cargo.toml" && info+=("%F{#ff4500}%B($(echo "$versions" | grep rust | cut -d ' ' -f2))%b%f")
    file_exists "$git_root_path" "go.mod" && info+=("%F{cyan}%B($(echo "$versions" | grep go | cut -d ' ' -f2))%b%f")

  fi
  echo ${(j: :)info}
}

# from pretty-time-zsh
function to_human_time() {
  local human total_seconds=$1
  local days=$(( total_seconds / 60 / 60 / 24 ))
  local hours=$(( total_seconds / 60 / 60 % 24 ))
  local minutes=$(( total_seconds / 60 % 60 ))
  local seconds=$(( total_seconds % 60 ))

  (( days > 0 )) && human+="${days}d "
  (( hours > 0 )) && human+="${hours}h "
  (( minutes > 0 )) && human+="${minutes}m "
  human+="${seconds}s"

  echo "$human"
}
