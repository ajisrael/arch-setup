{ pkgs, ... }:
{
  home.username = "ajisrael";
  home.homeDirectory = "/home/ajisrael";
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  programs.git = {
    enable = true;
    settings.user = {
      name = "Alex Israels";
      email = "43039187+ajisrael@users.noreply.github.com";
    };
  };

  home.packages = [ pkgs.hello ];
}
