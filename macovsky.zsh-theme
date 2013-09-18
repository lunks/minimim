  local pwd="${PWD/#$HOME/~}"

  if [[ "$pwd" == (#m)[/~] ]]; then
    _prompt_sorin_pwd="$MATCH"
    unset MATCH
  else
    _prompt_sorin_pwd="${${${(@j:/:M)${(@s:/:)pwd}##.#?}:h}%/}/${pwd:t}"
  fi


PROMPT='%{$fg[green]%}$prompt_sorin_pwd%{$reset_color%} %{$fg[red]%}‹$(rvm-prompt v g 2>/dev/null)› %{$reset_color%} $(git_prompt_info)%{$reset_color%}%B$%b '

ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg[yellow]%}‹"
ZSH_THEME_GIT_PROMPT_SUFFIX="› %{$reset_color%}"
