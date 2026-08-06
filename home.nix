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

  home.packages = [ pkgs.hello ];

  # Live-editable configs: plain files in the repo, symlinked into ~/.config.
  # Editing the file in place is instantly picked up - no re-switch needed.
  home.file = let
    repo = "/home/ajisrael/arch-setup";
    link = path:
      config.lib.file.mkOutOfStoreSymlink "${repo}/config/${path}";
  in {
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
