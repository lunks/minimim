# Load zsh/datetime module to be able to access `$EPOCHSECONDS`
zmodload zsh/datetime || return

typeset -g prompt_command_timestamp
typeset -g prompt_command_elapsed

function PCMD() {
  echo "%F{green}$(PR_DIR) %B$%b %{$reset_color%}"
}

function RCMD() {
  echo "$prompt_command_elapsed$(git_prompt_string)$(ruby_version)$(nodejs_version)%{$reset_color%}"
}

function ruby_version() {
  (( $+commands[ruby] )) || return 1
  test -f Gemfile || return 1
  MM_RUBY_FULL="$(ruby -v 2>/dev/null)"
  [[ $MM_RUBY_FULL =~ 'ruby ([0-9A-Za-z.]+)p[0-9]+' ]]
  MM_RUBY_VERSION=$match[1]

  echo " %F{red}%B(%b%F{red}$MM_RUBY_VERSION%B)%b"
}

function nodejs_version() {
  (( $+commands[node] )) || return 1
  test -f package.json || return 1
  MM_NODE_FULL="$(node -v 2>/dev/null)"
  [[ $MM_NODE_FULL =~ 'v([0-9A-Za-z.]+)' ]]
  MM_NODE_VERSION=$match[1]
  echo " %F{green}%B(%b%F{green}$MM_NODE_VERSION%B)%b"
}

PROMPT='$(PCMD)'
RPROMPT='' # no initial prompt, set dynamically

function PR_DIR() {
  local start_path="$(print -P "%-1~")"
  local end_path="$(print -P "%2~")"


  local prompt="$start_path/$end_path"

  if [[ $end_path = *"$start_path"* ]] ; then
    prompt="$end_path"
  fi

  echo "$prompt"
}

# Set RHS prompt for git repositories
DIFF_SYMBOL="-"
GIT_PROMPT_SYMBOL=""
GIT_PROMPT_PREFIX="%{$fg[yellow]%}%B(%b%{$reset_color%}"
GIT_PROMPT_SUFFIX="%{$fg[yellow]%}%B)%b%{$reset_color%}"
GIT_PROMPT_AHEAD="%{$fg[teal]%}%B+NUM%b%{$reset_color%}"
GIT_PROMPT_BEHIND="%{$fg[orange]%}%B-NUM%b%{$reset_color%}"
GIT_PROMPT_MERGING="%{$fg[cyan]%}%Bx%b%{$reset_color%}"
GIT_PROMPT_UNTRACKED="%{$fg[red]%}%B$DIFF_SYMBOL%b%{$reset_color%}"
GIT_PROMPT_MODIFIED="%{$fg[yellow]%}%B$DIFF_SYMBOL%b%{$reset_color%}"
GIT_PROMPT_STAGED="%{$fg[green]%}%B$DIFF_SYMBOL%b%{$reset_color%}"
GIT_PROMPT_DETACHED="%{$fg[neon]%}%B!%b%{$reset_color%}"

# Show Git branch/tag, or name-rev if on detached head
function parse_git_branch() {
  (git symbolic-ref -q HEAD || git name-rev --name-only --no-undefined --always HEAD) 2> /dev/null
}

function parse_git_detached() {
  if ! git symbolic-ref HEAD >/dev/null 2>&1; then
    echo "${GIT_PROMPT_DETACHED}"
  fi
}

# Show different symbols as appropriate for various Git repository states
function parse_git_state() {
  # Compose this value via multiple conditional appends.
  local GIT_STATE=""

  local NUM_AHEAD="$(git log --oneline @{u}.. 2> /dev/null | wc -l | tr -d ' ')"
  if [ "$NUM_AHEAD" -gt 0 ]; then
    GIT_STATE=$GIT_STATE${GIT_PROMPT_AHEAD//NUM/$NUM_AHEAD}
  fi

  local NUM_BEHIND="$(git log --oneline ..@{u} 2> /dev/null | wc -l | tr -d ' ')"
  if [ "$NUM_BEHIND" -gt 0 ]; then
    if [[ -n $GIT_STATE ]]; then
      GIT_STATE="$GIT_STATE "
    fi
    GIT_STATE=$GIT_STATE${GIT_PROMPT_BEHIND//NUM/$NUM_BEHIND}
  fi

  local GIT_DIR="$(git rev-parse --git-dir 2> /dev/null)"
  if [ -n $GIT_DIR ] && test -r $GIT_DIR/MERGE_HEAD; then
    if [[ -n $GIT_STATE ]]; then
      GIT_STATE="$GIT_STATE "
    fi
    GIT_STATE=$GIT_STATE$GIT_PROMPT_MERGING
  fi

  if [[ -n $(git ls-files --other --exclude-standard :/ 2> /dev/null) ]]; then
    GIT_DIFF=$GIT_PROMPT_UNTRACKED
  fi

  if ! git diff --quiet 2> /dev/null; then
    GIT_DIFF=$GIT_DIFF$GIT_PROMPT_MODIFIED
  fi

  if ! git diff --cached --quiet 2> /dev/null; then
    GIT_DIFF=$GIT_DIFF$GIT_PROMPT_STAGED
  fi

  if [[ -n $GIT_STATE && -n $GIT_DIFF ]]; then
    GIT_STATE="$GIT_STATE "
  fi
  GIT_STATE="$GIT_STATE$GIT_DIFF"

  if [[ -n $GIT_STATE ]]; then
    echo "$GIT_PROMPT_PREFIX$GIT_STATE$GIT_PROMPT_SUFFIX"
  fi
}

# If inside a Git repository, print its branch and state
RPR_SHOW_GIT=true # Set to false to disable git status in rhs prompt
function git_prompt_string() {
  if [[ "${RPR_SHOW_GIT}" == "true" ]]; then
    local git_where="$(parse_git_branch)"
    local git_detached="$(parse_git_detached)"
    [ -n "$git_where" ] && echo " $GIT_PROMPT_SYMBOL$(parse_git_state)$GIT_PROMPT_PREFIX%{$fg[yellow]%}${git_where#(refs/heads/|tags/)}%b$git_detached$GIT_PROMPT_SUFFIX"
  fi
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

function preexec() {
  prompt_command_timestamp=$EPOCHSECONDS
}

ASYNC_PROC=0
function precmd() {
  local elapsed

  prompt_command_elapsed=

  (( elapsed = EPOCHSECONDS - ${prompt_command_timestamp:-$EPOCHSECONDS} ))

  if (( elapsed > 5 )); then
    prompt_command_elapsed="$(to_human_time $elapsed) "
  fi

  prompt_command_timestamp=

  function async() {
    # save to temp file
    printf "%s" "$(RCMD)" > "${HOME}/.zsh_tmp_prompt"
    # signal parent
    kill -s USR1 $$
  }

  # do not clear RPROMPT, let it persist

  # kill child if necessary
  if [[ "${ASYNC_PROC}" != 0 ]]; then
    kill -s HUP $ASYNC_PROC >/dev/null 2>&1 || :
  fi

  # start background computation
  async &!
  ASYNC_PROC=$!
}

function TRAPUSR1() {
  # read from temp file
  RPROMPT="$(cat ${HOME}/.zsh_tmp_prompt)"

  # reset proc number
  ASYNC_PROC=0

  # redisplay
  zle && zle reset-prompt
}



