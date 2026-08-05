{ pkgs, ... }:
{
  home.username = "ajisrael";
  home.homeDirectory = "/home/ajisrael";
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  home.packages = [ pkgs.hello ];
}
