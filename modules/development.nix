{ lib, pkgs, username, ... }:

{
  imports = [ ./development-core.nix ];

  virtualisation.docker = {
    enable = true;
    enableOnBoot = false;
  };

  # NixOS enables docker.socket even with enableOnBoot = false, which starts
  # dockerd as soon as a client touches the socket. Keep Docker fully manual;
  # starting docker.service will pull in its required socket when needed.
  systemd.sockets.docker.wantedBy = lib.mkForce [ ];

  users.users.${username}.extraGroups = [ "docker" ];

  environment.systemPackages = with pkgs; [
    docker-compose
    lazydocker
    lazyssh
  ];
}
