{ hostName, inputs, lib, pkgs, resolvedHostModules, systemSettings, userDescription, username, ... }:

let
  settings = {
    bootTimeout = 1;
    enableVivobookS15 = false;
    ignoreLidSwitch = false;
    lanMousePeerHost = null;
    stateVersion = "26.05";
    useLatestKernel = false;
  } // systemSettings;
in
{
  imports =
    lib.optionals resolvedHostModules.x1e [ inputs.x1e-nixos-config.nixosModules.x1e ]
    ++ lib.optionals resolvedHostModules.common [ ./common.nix ]
    ++ lib.optionals resolvedHostModules.bootSplash [ ./boot-splash.nix ]
    ++ lib.optionals resolvedHostModules.desktop [ ./desktop.nix ]
    ++ lib.optionals resolvedHostModules.developmentCore [ ./development-core.nix ]
    ++ lib.optionals resolvedHostModules.hardwareAmdGpu [ ./hardware-amd-gpu.nix ]
    ++ lib.optionals resolvedHostModules.hardwareAsusLaptop [ ./hardware-asus-laptop.nix ]
    ++ lib.optionals resolvedHostModules.lanMouse [ ./lan-mouse.nix ];

  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    loader.timeout = settings.bootTimeout;
  } // lib.optionalAttrs settings.useLatestKernel {
    kernelPackages = pkgs.linuxPackages_latest;
  };

  hardware = {
    # Wi-Fi, Bluetooth and GPUs on every supported host require firmware that
    # is not part of the fully free set; this must not depend on one ARM model.
    enableRedistributableFirmware = true;
  } // lib.optionalAttrs settings.enableVivobookS15 {
    asus-vivobook-s15.enable = true;
  };

  networking.hostName = hostName;
  networking.networkmanager.enable = true;

  services =
    lib.optionalAttrs resolvedHostModules.lanMouse {
      lanMouse = {
        enable = true;
      } // lib.optionalAttrs (settings.lanMousePeerHost != null) {
        peerHost = settings.lanMousePeerHost;
      };
    }
    // lib.optionalAttrs settings.ignoreLidSwitch {
      logind.settings.Login = {
        HandleLidSwitch = "ignore";
        HandleLidSwitchExternalPower = "ignore";
        HandleLidSwitchDocked = "ignore";
      };
    }
    // {
      xserver.xkb = {
        layout = "pl";
        variant = "";
      };
    };

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "pl_PL.UTF-8";
    LC_IDENTIFICATION = "pl_PL.UTF-8";
    LC_MEASUREMENT = "pl_PL.UTF-8";
    LC_MONETARY = "pl_PL.UTF-8";
    LC_NAME = "pl_PL.UTF-8";
    LC_NUMERIC = "pl_PL.UTF-8";
    LC_PAPER = "pl_PL.UTF-8";
    LC_TELEPHONE = "pl_PL.UTF-8";
    LC_TIME = "pl_PL.UTF-8";
  };

  console.keyMap = "pl2";

  users.users.${username} = {
    isNormalUser = true;
    description = userDescription;
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.fish;
  };

  nixpkgs.config.allowUnfree = true;
  system.stateVersion = settings.stateVersion;
}
