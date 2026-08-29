{ config, hostName, lib, pkgs, ... }:

let
  cfg = config.services.deskflow;

  serverConfig = pkgs.writeText "deskflow-server.conf" ''
    # The server owns the physical keyboard and mouse. Keep both screen names
    # stable because the client identifies itself with its host name.
    section: screens
      ${hostName}:
      ${cfg.peerName}:
    end

    section: links
      ${hostName}:
        right = ${cfg.peerName}
      ${cfg.peerName}:
        left = ${hostName}
    end

    # The remote machine has no separate local monitor in this session, so use
    # keyboard-only switching instead of relying on moving the pointer to an
    # invisible screen edge. These combinations are intentionally not Super
    # bindings, so Hyprland keeps Super+number available for remote shortcuts.
    section: options
      keystroke(control+alt+F12) = switchToScreen(${cfg.peerName})
      keystroke(control+alt+F11) = switchToScreen(${hostName})
    end
  '';

  settings = pkgs.writeText "Deskflow.conf" ''
    [core]
    coreMode=${if cfg.role == "server" then "2" else "1"}
    computerName=${hostName}
    port=24800

    ${lib.optionalString (cfg.role == "server") ''
      [server]
      externalConfig=true
      externalConfigFile=deskflow-server.conf
    ''}

    ${lib.optionalString (cfg.role == "client") ''
      [client]
      remoteHost=${cfg.serverAddress}
    ''}
  '';

  # Deskflow resolves externalConfigFile relative to the settings file. Keep
  # both generated files in one directory so the immutable Nix store path does
  # not get reduced to /nix/store/deskflow-server.conf at runtime.
  settingsDirectory = pkgs.linkFarm "deskflow-${cfg.role}-settings" (
    [
      {
        name = "Deskflow.conf";
        path = settings;
      }
    ]
    ++ lib.optional (cfg.role == "server") {
      name = "deskflow-server.conf";
      path = serverConfig;
    }
  );

  command = "${pkgs.deskflow}/bin/deskflow-core ${cfg.role} --settings ${settingsDirectory}/Deskflow.conf";
in
{
  options.services.deskflow = {
    enable = lib.mkEnableOption "Deskflow keyboard and mouse sharing";

    role = lib.mkOption {
      type = lib.types.enum [ "server" "client" ];
      default = "client";
      description = "Whether this host owns the physical input devices or receives shared input.";
    };

    peerName = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Deskflow screen name of the paired client; required on the server.";
    };

    serverAddress = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Hostname or address of the Deskflow server; required on the client.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.role != "server" || cfg.peerName != null;
        message = "services.deskflow.peerName is required when Deskflow runs as a server.";
      }
      {
        assertion = cfg.role != "client" || cfg.serverAddress != null;
        message = "services.deskflow.serverAddress is required when Deskflow runs as a client.";
      }
    ];

    environment.systemPackages = [ pkgs.deskflow ];

    networking.firewall.allowedTCPPorts = lib.mkIf (cfg.role == "server") [ 24800 ];

    systemd.user.services.deskflow = {
      description = "Deskflow keyboard and mouse sharing";
      after = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      wantedBy = [ "graphical-session.target" ];
      unitConfig.ConditionEnvironment = "WAYLAND_DISPLAY";
      serviceConfig = {
        ExecStart = command;
        WorkingDirectory = settingsDirectory;
        Restart = "on-failure";
        RestartSec = 2;
      };
    };
  };
}
