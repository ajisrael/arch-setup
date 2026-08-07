# Sourced last from the home-manager-generated ~/.zshrc (programs.zsh's
# initContent), after oh-my-zsh has loaded. Unlike the macOS dotfiles,
# home-manager owns ~/.zshenv/.zprofile here, so session vars and PATH come
# from those - this file holds the bits that differ from the generated config.
#
# Dropped from the macOS version: nvm lazy-load (not installed on archeus),
# brew/VSCode/Python framework paths, envman, bun, podman DOCKER_HOST, and the
# firstmate helper - all macOS-machine-specific.

# Preferred editor for local and remote sessions
export EDITOR='nvim'

alias vim="nvim"

# opencode: load the MCP server secrets (repo-root .env, decrypted by
# build/decrypt-secrets.sh) into the session env, then launch. Uses the full
# path to the binary so the alias doesn't recurse; the source is guarded
# because .env won't exist on a fresh clone.
alias opencode='if [[ -f /home/ajisrael/arch-setup/.env ]]; then set -a; source /home/ajisrael/arch-setup/.env; set +a; fi; /usr/bin/opencode'

# Keybindings
bindkey -s ^f "tmux-sessionizer\n"

# Rename the tmux window to the running program (mapped to a friendlier
# name), then back to "zsh" once it exits. Uses $TMUX_PANE (not plain
# `tmux rename-window`) because a terminal wrapper in front of this shell
# puts it on a pty tmux isn't directly watching, so pane_current_command
# and automatic-rename can't see through it.
if [[ -n "$TMUX" ]]; then
  _tmux_window_name_for_cmd() {
    local cmd="${1%% *}"
    case "$cmd" in
      claude) echo "claude-code" ;;
      nvim|vim) echo "vim" ;;
      *) echo "$cmd" ;;
    esac
  }
  _tmux_rename_preexec() {
    tmux rename-window -t "$TMUX_PANE" "$(_tmux_window_name_for_cmd "$1")"
  }
  _tmux_rename_precmd() {
    tmux rename-window -t "$TMUX_PANE" "zsh"
  }
  autoload -Uz add-zsh-hook
  add-zsh-hook preexec _tmux_rename_preexec
  add-zsh-hook precmd _tmux_rename_precmd
fi

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# tmux-sessionizer lives in the repo; home.nix wires it onto PATH via
# home.sessionPath once the rebuild has run, this line keeps it working in
# the meantime (harmless duplicate afterward).
export PATH="$HOME/arch-setup/config/tmux/tmux-scripts:$PATH"
