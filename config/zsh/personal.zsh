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

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# tmux-sessionizer lives in the repo; home.nix wires it onto PATH via
# home.sessionPath once the rebuild has run, this line keeps it working in
# the meantime (harmless duplicate afterward).
export PATH="$HOME/arch-setup/config/tmux/tmux-scripts:$PATH"
