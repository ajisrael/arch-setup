{ pkgs, ... }:
{
  home.username = "ajisrael";
  home.homeDirectory = "/home/ajisrael";
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  programs.git = {
    enable = true;
    settings.user = {
      name = "ajisrael";
      email = "CHANGE-ME@example.com";
    };
  };

  home.packages = [ pkgs.hello ];
}
