{ pkgs, ... }:

{
  programs.fish.enable = true;

  virtualisation.docker = {
    enable = true;
    enableOnBoot = false;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  users.users.wojtek.extraGroups = [ "docker" ];

  environment.systemPackages = with pkgs; [
    codex
    docker-compose
    gnumake
    lazydocker
    lazyssh
  ];
}
