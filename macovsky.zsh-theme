zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:*:*' check-for-changes false
zstyle ':vcs_info:*' formats " %F{yellow}‹%s:%b%c%u›%f"
zstyle ':vcs_info:*' actionformats " %F{yellow}‹%a:%i:%b›%f"
zstyle ':vcs_info:git*+set-message:*' hooks git-abbrv-master
function +vi-git-abbrv-master() {
    hook_com[branch]=${hook_com[branch]/#%master/m}
}
autoload -Uz vcs_info
precmd() {
    vcs_info
    current_dir
}

function current_dir {
  local pwd="${PWD/#$HOME/~}"
    if [[ "$pwd" == (#m)[/~] ]]; then
      _prompt_sorin_pwd="$MATCH"
      unset MATCH
    else
      _prompt_sorin_pwd="${${${(@j:/:M)${(@s:/:)pwd}##.#?}:h}%/}/${pwd:t}"
    fi
}

PROMPT='%F{green}${_prompt_sorin_pwd}%f %F{red}‹$(rbenv version | sed -e "s/ (set.*$//")›%f${vcs_info_msg_0_} %B$%b '
