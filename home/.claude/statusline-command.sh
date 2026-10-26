  #!/bin/sh                                                                                                                                                 
  input=$(cat)                                                                                                                                              
  cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')                                                                                    
  model=$(echo "$input" | jq -r '.model.display_name // empty')                                                                                             
  used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')                                                                                  
  tokens=$(echo "$input" | jq -r '((.context_window.current_usage.input_tokens // 0) + (.context_window.current_usage.cache_creation_input_tokens // 0) +   
  (.context_window.current_usage.cache_read_input_tokens // 0))')
  home="$HOME"
  short_cwd="${cwd/#$home/~}"
  git_branch=""
  if git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
    git_branch=$(git -C "$cwd" -c gc.auto=0 symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" -c gc.auto=0 rev-parse --short HEAD 2>/dev/null)
  fi
  parts=$(printf "\033[36m%s\033[0m" "$short_cwd")
  if [ -n "$git_branch" ]; then
    parts=$(printf "%s \033[32m %s\033[0m" "$parts" "$git_branch")
  fi
  parts=$(printf "%s \033[90m|\033[0m" "$parts")
  if [ -n "$used" ]; then
    used_int=$(printf "%.0f" "$used")
    filled=$(( used_int / 10 )); empty=$(( 10 - filled ))
    bar_filled=""; bar_empty=""; i=0
    while [ $i -lt $filled ]; do bar_filled="${bar_filled}█"; i=$(( i + 1 )); done
    i=0
    while [ $i -lt $empty ]; do bar_empty="${bar_empty}░"; i=$(( i + 1 )); done
    if [ "$used_int" -ge 80 ]; then bar_color="\033[31m"
    elif [ "$used_int" -ge 60 ]; then bar_color="\033[33m"
    else bar_color="\033[32m"; fi
    token_str=""
    if [ "$tokens" -gt 0 ] 2>/dev/null; then token_str="$(( tokens / 1000 ))k"; fi
    bar=$(printf "${bar_color}%s\033[90m%s\033[0m %s%%" "$bar_filled" "$bar_empty" "$used_int")
    if [ -n "$token_str" ]; then bar=$(printf "%s \033[90m%s\033[0m" "$bar" "$token_str"); fi
  fi
  if [ -n "$model" ] && [ -n "$bar" ]; then
    parts=$(printf "%s \033[37m%s\033[0m %s" "$parts" "$model" "$bar")
  elif [ -n "$model" ]; then
    parts=$(printf "%s \033[37m%s\033[0m" "$parts" "$model")
  fi
  printf "%s" "$parts"