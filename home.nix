{ pkgs, config, ... }:
{
  home.username = "ajisrael";
  home.homeDirectory = "/home/ajisrael";
  home.stateVersion = "26.05";

  targets.genericLinux.enable = true;

  programs.home-manager.enable = true;

  programs.git = {
    enable = true;
    settings.user = {
      name = "Alex Israels";
      email = "43039187+ajisrael@users.noreply.github.com";
    };
  };

  # Key is named ~/.ssh/github (not a default identity file), so pin it to the
  # host - otherwise ssh only offers it when it is loaded into the agent.
  # enableDefaultConfig = false keeps home-manager from injecting its own
  # defaults; the "Host *" block below replicates them explicitly.
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "*" = {
        ForwardAgent = false;
        AddKeysToAgent = "no";
        Compression = false;
        ServerAliveInterval = 0;
        ServerAliveCountMax = 3;
        HashKnownHosts = false;
        UserKnownHostsFile = "~/.ssh/known_hosts";
        ControlMaster = "no";
        ControlPath = "~/.ssh/master-%r@%n:%p";
        ControlPersist = "no";
      };
      "github.com" = {
        HostName = "github.com";
        User = "git";
        IdentityFile = "~/.ssh/github";
        IdentitiesOnly = true;
      };
    };
  };

  home.packages = [ pkgs.hello ];

  # Live-editable configs: plain files in the repo, symlinked into ~/.config.
  # Editing the file in place is instantly picked up - no re-switch needed.
  home.file = let
    repo = "/home/ajisrael/arch-setup";
    link = path:
      config.lib.file.mkOutOfStoreSymlink "${repo}/config/${path}";
  in {
    ".ssh/config".force = true; # programs.ssh generates it; clobber the pre-flake file
    ".bashrc" = {
      source = link "bash/bashrc";
      force = true; # clobber the stock ~/.bashrc so home-manager owns it
    };
    ".bash_profile" = {
      source = link "bash/bash_profile";
      force = true; # login shells (tty1/ssh) delegate to ~/.bashrc
    };
    ".config/hypr/hyprland.lua" = {
      source = link "hypr/hyprland.lua";
      force = true; # clobbers the auto-generated config from the first start-hyprland
    };
    ".config/hypr/hyprlock.conf".source = link "hypr/hyprlock.conf";
    ".config/hypr/hyprpaper.conf".source = link "hypr/hyprpaper.conf";
    ".config/kitty/kitty.conf".source = link "kitty/kitty.conf";
    ".config/mako/config".source = link "mako/config";
    ".config/wofi/config".source = link "wofi/config";
    ".config/waybar/config.jsonc".source = link "waybar/config.jsonc";
    ".config/waybar/style.css".source = link "waybar/style.css";
  };
}
