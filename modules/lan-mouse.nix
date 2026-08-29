{ config, lib, pkgs, username, ... }:

let
  cfg = config.services.lanMouse;
  stateDirectory = "${config.users.users.${username}.home}/.config/lan-mouse";

  initialConfig = pkgs.writeText "lan-mouse-config.toml" ''
    # This file is created only on the first start. Lan Mouse adds trusted
    # peer fingerprints here after the user approves the pairing; do not
    # overwrite it from Nix, because fingerprints are mutable credentials.
    port = ${toString cfg.port}

    ${lib.optionalString (cfg.peerHost != null) ''
      [[clients]]
      # ROG hands input to White Monster at the right screen edge.
      position = "${cfg.peerPosition}"
      hostname = "${cfg.peerHost}"
      activate_on_startup = true
    ''}
  '';

  initializeConfig = pkgs.writeShellScript "lan-mouse-initialize-config" ''
    config_file="${stateDirectory}/config.toml"
    ${pkgs.coreutils}/bin/mkdir -p "${stateDirectory}"
    if [ ! -e "$config_file" ]; then
      ${pkgs.coreutils}/bin/install -m 600 "${initialConfig}" "$config_file"
    fi
  '';
in
{
  options.services.lanMouse = {
    enable = lib.mkEnableOption "Lan Mouse keyboard and mouse sharing";

    peerHost = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Hostname of the computer controlled when the pointer reaches the configured edge.";
    };

    peerPosition = lib.mkOption {
      type = lib.types.enum [ "left" "right" "top" "bottom" ];
      default = "right";
      description = "Screen edge through which the local keyboard and mouse enter peerHost.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 4242;
      description = "UDP port used for encrypted Lan Mouse traffic on the trusted LAN.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.lan-mouse ];

    networking.firewall.allowedUDPPorts = [ cfg.port ];

    systemd.user.services.lan-mouse = {
      description = "Lan Mouse keyboard and mouse sharing";
      after = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      wantedBy = [ "graphical-session.target" ];
      unitConfig.ConditionEnvironment = "WAYLAND_DISPLAY";
      serviceConfig = {
        ExecStartPre = initializeConfig;
        # xdg-desktop-portal 1.22.1 aborts in InputCapture.ConnectToEIS on
        # this Hyprland setup, leaving Wayland clients unable to flush. The
        # layer-shell backend uses edge surfaces instead, so it keeps Lan Mouse
        # independent from that unstable portal path on both hosts.
        ExecStart = "${pkgs.lan-mouse}/bin/lan-mouse --capture-backend layer-shell daemon";
        Restart = "on-failure";
        RestartSec = 2;
      };
    };
  };
}
