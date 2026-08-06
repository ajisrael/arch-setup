# prompt.bashrc - Tokyo Night bash prompt for archeus.
#
# Approximates the macOS Powerlevel10k prompt (dotfiles/home/p10k.zsh):
#   line 1:  linux icon  full path  git status
#            (right margin: exit status, command duration, background jobs,
#             python/node/java envs, current time)
#   line 2:  prompt char (❯)
# plus a blank line before the prompt and p10k's Tokyo Night colors.
#
# Rendering mode is picked from $TERM:
#   * TERM=linux (tty1/VTs): 256-color approximations and plain glyphs, since
#     the Linux console font cannot render nerd-font/unicode icons.
#   * anything else (kitty, tmux, ssh): truecolor + nerd-font glyphs
#     (MesloLGS NF, installed via system-packages.nix).
# A plain-text copy of the right side is kept so the ANSI cursor-alignment
# trick can place it at the right margin without counting escape bytes.
#
# Sourced from bashrc (interactive shells only).

case $- in *i*) ;; *) return 0 ;; esac

# ---- mode + colors (Tokyo Night) --------------------------------------------
__p_mode=graphics
[[ ${TERM:-} == linux ]] && __p_mode=linux

__p_fg() { # $1=color name -> SGR color fragment (truecolor or 256-color)
  if [[ $__p_mode == graphics ]]; then
    case $1 in
      yellow) printf '38;2;224;175;104';; # e0af68
      blue)   printf '38;2;122;162;247';; # 7aa2f7
      green)  printf '38;2;158;206;106';; # 9ece6a
      red)    printf '38;2;247;118;142';; # f7768e
      grey)   printf '38;2;169;177;214';; # a9b1d6
      cyan)   printf '38;2;125;207;255';; # 7dcfff
      purple) printf '38;2;187;154;247';; # bb9af7
      orange) printf '38;2;255;158;100';; # ff9e64
      white)  printf '38;2;192;202;245';; # c0caf5
    esac
  else
    case $1 in
      yellow) printf '38;5;179';; # nearest to e0af68
      blue)   printf '38;5;111';; # nearest to 7aa2f7
      green)  printf '38;5;149';; # nearest to 9ece6a
      red)    printf '38;5;210';; # nearest to f7768e
      grey)   printf '38;5;146';; # nearest to a9b1d6
      cyan)   printf '38;5;117';; # nearest to 7dcfff
      purple) printf '38;5;141';; # nearest to bb9af7
      orange) printf '38;5;216';; # nearest to ff9e64
      white)  printf '38;5;189';; # nearest to c0caf5
    esac
  fi
}

# wrapped codes: for the LEFT side, so bash only counts visible text for
# line-wrapping. The \e stays literal here and bash expands it in PS1.
__p_wrap() { # $1=color $2=text [$3=bold]
  local bold=''
  [[ -n ${3:-} ]] && bold=';1'
  printf '%s%s%s%s%s%s' '\[\e[' "$(__p_fg "$1")" "$bold" 'm\]' "$2" '\[\e[0m\]'
}

# raw codes: for the RIGHT side, which sits inside one \[ \] block anyway.
__p_raw() { # $1=color $2=text
  printf '\033[%sm%s\033[0m' "$(__p_fg "$1")" "$2"
}

# ---- glyphs ------------------------------------------------------------------
__p_glyph() { printf '%b' "\\U$(printf '%08x' "$1")"; }

if [[ $__p_mode == graphics ]]; then
  G_ARCH=$(__p_glyph 0xf31c)    #  arch linux
  G_HOME=$(__p_glyph 0xf015)    #  home
  G_FOLDER=$(__p_glyph 0xf07b)  #  folder
  G_BRANCH=$(__p_glyph 0xf126)  #  git branch
  G_CLOCK=$(__p_glyph 0xf017)   #  clock
  G_GEAR=$(__p_glyph 0xf013)    #  gear
  G_TIMER=$(__p_glyph 0xf43a)   #  timer
  G_PY=$(__p_glyph 0xe235)      #  python
  G_NODE=$(__p_glyph 0xe718)    #  node
  G_JAVA=$(__p_glyph 0xe256)    #  java
  G_ERR=$(__p_glyph 0x2718)     #  x
  G_CHEVRON=$(__p_glyph 0x276f) #  >
  G_UP=$(__p_glyph 0x21e1)      #  ahead
  G_DN=$(__p_glyph 0x21e3)      #  behind
  G_DIV=$(__p_glyph 0x21d5)     #  diverged
  G_MODIFIED=$(__p_glyph 0x00b1) # +/-
else
  G_ARCH= G_HOME= G_FOLDER= G_BRANCH= G_CLOCK= G_GEAR= G_TIMER= G_PY= G_NODE= G_JAVA=
  G_ERR='!'
  G_CHEVRON='>'
  G_UP='+' G_DN='-' G_DIV='<>'
  G_MODIFIED='*'
fi
G_STAGED='+' G_UNTRACKED='?'

# ---- segments ----------------------------------------------------------------
declare -g __p_git_dir= __p_git_t=0 __p_git_fg=green __p_git_marks= \
  __p_git_branch= __p_vcs= __p_node_ver= __p_env_t=0

__p_os() { # linux icon (nerd font only)
  [[ $__p_mode == graphics ]] && __p_wrap cyan "$G_ARCH"
}

__p_dir() { # full path; home icon in ~, folder icon elsewhere + ~, last bold
  local p=${PWD/#$HOME/\~}
  local out=
  local -a parts=()
  local n last i
  if [[ $p == '~' ]]; then
    [[ $__p_mode == graphics ]] && out+="$(__p_wrap blue "$G_HOME") "
    out+="$(__p_wrap white '~' bold)"
  else
    local IFS=/
    if [[ $p == \~/* ]]; then
      [[ $__p_mode == graphics ]] && out+="$(__p_wrap blue "$G_FOLDER") "
      out+="$(__p_wrap blue '~')"
      read -r -a parts <<< "${p:2}"
    else
      [[ $__p_mode == graphics ]] && out+="$(__p_wrap blue "$G_FOLDER") "
      read -r -a parts <<< "${p:1}"
    fi
    n=${#parts[@]}
    if (( n == 0 )); then
      out+="$(__p_wrap white '/' bold)"
    else
      last=${parts[n-1]}
      for (( i=0; i<n-1; i++ )); do
        out+="$(__p_wrap blue "/${parts[i]}")"
      done
      out+="$(__p_wrap white "/$last" bold)"
    fi
  fi
  printf '%s' "$out"
}

__p_git() { # branch + ahead/behind + dirty/staged/untracked marks, one git call
  __p_vcs=
  local now=${EPOCHREALTIME%%.*}
  local wd=$PWD
  if [[ $wd != "$__p_git_dir" || $(( now - __p_git_t )) -gt 2 ]]; then
    local out
    if ! out=$(git status --porcelain=2 --branch 2>/dev/null); then
      __p_git_dir=$wd; __p_git_t=$now; __p_git_branch=
      return
    fi
    __p_git_dir=$wd; __p_git_t=$now
    local branch= oid= ahead=0 behind=0 staged=0 modified=0 untracked=0
    local line xy
    while IFS= read -r line; do
      case $line in
        '# branch.head '*) branch=${line#*'# branch.head '} ;;
        '# branch.oid '*)  oid=${line#*'# branch.oid '} ;;
        '# branch.ab '*)   local ab=${line#*'# branch.ab '}
          ahead=${ab%% *}; ahead=${ahead#+}
          behind=${ab##* }; behind=${behind#-} ;;
        \?*) ((untracked++)) ;;
        *)
          [[ ${line:0:1} == '#' ]] && continue
          xy=${line:2:2}
          [[ ${xy:0:1} != ' ' && ${xy:0:1} != '.' ]] && ((staged++))
          [[ ${xy:1:1} != ' ' && ${xy:1:1} != '.' ]] && ((modified++))
          ;;
      esac
    done <<< "$out"
    [[ $branch == 'HEAD (no branch)' ]] && branch=${oid:0:7}
    __p_git_branch=$branch
    __p_git_marks=
    (( ahead > 0 ))    && __p_git_marks+=" ${G_UP}${ahead}"
    (( behind > 0 ))   && __p_git_marks+=" ${G_DN}${behind}"
    (( staged > 0 ))   && __p_git_marks+=" ${G_STAGED}"
    (( modified > 0 )) && __p_git_marks+=" ${G_MODIFIED}"
    (( untracked > 0 )) && __p_git_marks+=" ${G_UNTRACKED}"
    if (( staged > 0 )); then
      __p_git_fg=purple
    elif (( modified > 0 || untracked > 0 )); then
      __p_git_fg=yellow
    else
      __p_git_fg=green
    fi
  fi
  if [[ -n $__p_git_branch ]]; then
    __p_vcs="$(__p_wrap "$__p_git_fg" " ${G_BRANCH}${G_BRANCH:+ }${__p_git_branch}${__p_git_marks}")"
  fi
}

__p_env() { # python/node/java, only while that env is active (right side)
  __p_env_raw=
  __p_env_plain=
  local now=${EPOCHREALTIME%%.*}
  if [[ -n ${VIRTUAL_ENV:-} ]]; then
    __p_env_raw+="$(__p_raw green "${G_PY} ${VIRTUAL_ENV##*/}") "
    __p_env_plain+="${G_PY} ${VIRTUAL_ENV##*/} "
  elif [[ -n ${CONDA_DEFAULT_ENV:-} ]]; then
    __p_env_raw+="$(__p_raw green "${G_PY} ${CONDA_DEFAULT_ENV##*/}") "
    __p_env_plain+="${G_PY} ${CONDA_DEFAULT_ENV##*/} "
  fi
  if [[ -n ${NVM_BIN:-} || -n ${FNM_DIR:-} || -n ${VOLTA_HOME:-} ]]; then
    if (( now - __p_env_t > 5 )); then
      __p_env_t=$now
      __p_node_ver=$(node --version 2>/dev/null)
    fi
    __p_env_raw+="$(__p_raw cyan "${G_NODE} ${__p_node_ver#v}") "
    __p_env_plain+="${G_NODE} ${__p_node_ver#v} "
  fi
  if [[ -n ${JAVA_HOME:-} ]]; then
    local jv
    jv=$(basename "$(readlink -f "$JAVA_HOME" 2>/dev/null)" 2>/dev/null)
    [[ -z $jv ]] && jv=${JAVA_HOME##*/}
    __p_env_raw+="$(__p_raw orange "${G_JAVA} ${jv}") "
    __p_env_plain+="${G_JAVA} ${jv} "
  fi
}

__p_fmtdur() { # $1=seconds $2=tenths
  if (( $1 >= 60 )); then
    printf '%dm %02ds' $(( $1 / 60 )) $(( $1 % 60 ))
  elif (( $1 >= 10 )); then
    printf '%ds' "$1"
  else
    printf '%s.%ss' "$1" "$2"
  fi
}

# ---- command execution time (DEBUG trap) --------------------------------------
# The DEBUG trap timestamps when the first command of a line starts; the next
# prompt measures elapsed time from there (p10k-style). A plain "time since the
# last prompt" would count idle/typing time too, so it is not used.
declare -g __p_in_cmd=false __p_cmd_start_us=0

__p_now_us() { # current epoch time in microseconds
  if [[ -v EPOCHREALTIME ]]; then
    printf '%s' "$(( 10#${EPOCHREALTIME%.*} * 1000000 + 10#${EPOCHREALTIME#*.} ))"
  else
    printf '%s' "$(( $(date +%s) * 1000000 ))"
  fi
}

__p_debug() { # DEBUG trap: timestamp the start of the first command after a prompt
  if [[ $__p_in_cmd == false ]]; then
    __p_in_cmd=true
    __p_cmd_start_us=$(__p_now_us)
  fi
  return 0
}
trap '__p_debug' DEBUG

# ---- prompt assembly ---------------------------------------------------------
__p_ps1() {
  local rc=$?
  local -i dur=0 frac=0
  if [[ $__p_in_cmd == true && $__p_cmd_start_us -gt 0 ]]; then
    local -i dur_us=$(( $(__p_now_us) - __p_cmd_start_us ))
    (( dur_us < 0 )) && dur_us=0
    dur=$(( dur_us / 1000000 ))
    frac=$(( (dur_us % 1000000) / 100000 ))
  fi
  __p_in_cmd=false
  __p_cmd_start_us=0

  # right side: exit status, duration, jobs, envs, time (p10k order)
  local right= plain= seg
  if (( rc != 0 )); then
    right+="$(__p_raw red "${G_ERR} ${rc}") "
    plain+="${G_ERR} ${rc} "
  fi
  if (( dur >= 3 )); then
    seg=$(__p_fmtdur "$dur" "$frac")
    right+="$(__p_raw orange "${G_TIMER} $seg") "
    plain+="${G_TIMER} $seg "
  fi
  local -i n_jobs
  n_jobs=$(jobs -p | wc -l | tr -d ' ')
  if (( n_jobs > 0 )); then
    right+="$(__p_raw cyan "$G_GEAR") "
    plain+="$G_GEAR "
  fi
  __p_env
  right+="$__p_env_raw"
  plain+="$__p_env_plain"
  right+="$(__p_raw grey "${G_CLOCK} $(date +%H:%M)")"
  plain+="${G_CLOCK} $(date +%H:%M)"

  # left side: os icon, path, git
  local left=
  __p_git
  left+="$(__p_os)"
  [[ -n $left ]] && left+=' '
  left+="$(__p_dir)"
  left+="$__p_vcs"

  local prompt_char="$(__p_wrap yellow "$G_CHEVRON")"

  # right-align via absolute column, then \r back to column 0 for the left side
  # (overwrites the right side on overlap, mirroring p10k hiding it on
  # collision). \r is used rather than DECSC/DECRC cursor save/restore - the
  # simplest thing that works in every terminal. Autowrap is toggled off while
  # printing the right side so it can't trigger a wrap-pending at the margin.
  local rp_len=${#plain}
  local pad=$(( ${COLUMNS:-80} - rp_len ))
  (( pad < 1 )) && pad=1

  PS1="\n\[\e[?7l\e[${pad}G\]\[${right}\]\[\e[?7h\r\]${left}\e[0m\n${prompt_char}\e[0m "
}

PROMPT_COMMAND=__p_ps1

# declare -g above already initializes the DEBUG-trap state, so a fresh shell
# (or re-source) shows no duration on the first prompt.
