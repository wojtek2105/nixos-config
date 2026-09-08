{ lib, pkgs, resolvedFeatures, username, ... }:

{
  virtualisation.docker = {
    enable = true;
    enableOnBoot = resolvedFeatures.dockerAutoStart;
  };

  # Without this, Docker socket activation could start dockerd on hosts that
  # opt out of boot startup. White Monster opts in through dockerAutoStart.
  systemd = lib.mkIf (!resolvedFeatures.dockerAutoStart) {
    sockets.docker.wantedBy = lib.mkForce [ ];
  };

  users.users.${username}.extraGroups = [ "docker" ];

  # Compose is needed to install and operate the user's container stack;
  # interactive desktop helpers do not belong on a headless server.
  environment.systemPackages = [ pkgs.docker-compose ];
}
