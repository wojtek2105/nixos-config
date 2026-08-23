{ pkgs, ... }:

{
  imports = [ ./development-core.nix ];

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
    docker-compose
    lazydocker
    lazyssh
  ];
}
