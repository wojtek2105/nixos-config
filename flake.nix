{
  description = "Custom NixOS build";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Keep Voxtype's TUI fixes independent from the wider NixOS package set.
    # v1.0.0-rc1 fixes the 0.7.5 editor regression that rejects its own saves.
    voxtype = {
      url = "github:peteonrails/voxtype/v1.0.0-rc1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Snapdragon X Elite needs a device-tree, initrd modules, firmware and a
    # kernel not yet supplied by the generic NixOS ARM64 installer.
    x1e-nixos-config = {
      url = "github:JamiKettunen/x1e-vivobook-nixos-config/vivobook";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    wlctl = {
      url = "github:aashish-thapa/wlctl";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    biscuit-nvim = {
      url = "github:Biscuit-Theme/nvim";
      flake = false;
    };

    # Upstream stays separate from the future personal Neovim repository.
    # Update this input deliberately when refreshing the Kickstart baseline.
    kickstart-nvim = {
      url = "github:nvim-lua/kickstart.nvim";
      flake = false;
    };

    biscuit-gtk = {
      url = "github:Biscuit-Theme/gtk";
      flake = false;
    };

    biscuit-desktop = {
      url = "github:OldJobobo/omarchy-biscuit-de-mar-dark-theme";
      flake = false;
    };
  };

  outputs =
    inputs@{ nixpkgs, home-manager, ... }:
    let
      defaultSystem = "x86_64-linux";
      pkgs = import nixpkgs {
        system = defaultSystem;
        config.allowUnfree = true;
      };
      # Benchmark dependencies stay outside system closures unless a host
      # explicitly enables features.schedulerBenchmark. The flake app remains
      # available on demand without changing the installed configuration.
      schedulerBenchmark = pkgs.callPackage ./tools/scheduler-benchmark { };
      defaultReplayConfig = {
        captureSource = "focused_monitor";
        fps = 60;
        seconds = 120;
        videoCodec = "hevc";
        videoBitrate = 25000;
        audioCodec = "opus";
      };
      defaultFeatures = {
        amdGpuMetrics = false;
        bluetooth = false;
        docker = false;
        gaming = false;
        hardwareDiagnostics = false;
        laptop = false;
        ollama = false;
        ollamaFarm = false;
        schedulerBenchmark = false;
        vr = false;
        personalApps = {
          discord = false;
          easyeffects = false;
          plexamp = false;
        };
        screenRecording = false;
        voxtype = false;
      };
      hostDirectories =
        nixpkgs.lib.filterAttrs
          (name: type:
            type == "directory"
            && builtins.pathExists (./hosts + "/${name}/default.nix")
            # A staged host is intentionally invisible until its own generated
            # hardware module is present. This prevents evaluating or, worse,
            # installing it with disk UUIDs copied from another machine.
            && builtins.pathExists (./hosts + "/${name}/hardware-configuration.nix"))
          (builtins.readDir ./hosts);
      mkHost = flakeHostName:
        {
          backlightDevice ? null,
          configuration,
          features ? { },
          hostModules ? { },
          hostName ? flakeHostName,
          homeOverlay ? null,
          homeProfile ? username,
          replayConfig ? { },
          system ? defaultSystem,
          systemSettings ? { },
          trackball ? null,
          uiScale ? 2,
          userDescription ? username,
          username,
        }:
        let
          homeModule = ./home + "/${homeProfile}/default.nix";
          themeModule = ./home/base/theme.nix;
          overlayModule = ./home + "/individual/${homeOverlay}/override.nix";
          desktopTheme = import themeModule { inherit inputs; };
          defaultHostModules = {
            common = false;
            bootSplash = false;
            desktop = false;
            developmentCore = false;
            hardwareAmdGpu = false;
            hardwareAsusLaptop = false;
            lanMouse = false;
            x1e = false;
          };
          providedHostModules = hostModules;
          unknownHostModules = builtins.filter
            (name: !(builtins.hasAttr name defaultHostModules))
            (builtins.attrNames providedHostModules);
          resolvedHostModules = defaultHostModules // providedHostModules;
          invalidHostModules = builtins.filter
            (name: !(builtins.isBool resolvedHostModules.${name}))
            (builtins.attrNames defaultHostModules);
          providedPersonalApps = features.personalApps or { };
          unknownFeatures = builtins.filter
            (name: !(builtins.hasAttr name defaultFeatures))
            (builtins.attrNames features);
          unknownPersonalApps = builtins.filter
            (name: !(builtins.hasAttr name defaultFeatures.personalApps))
            (builtins.attrNames providedPersonalApps);
          resolvedFeatures = defaultFeatures // features // {
            personalApps = defaultFeatures.personalApps // providedPersonalApps;
          };
          booleanFeatureNames = [
            "amdGpuMetrics"
            "bluetooth"
            "docker"
            "gaming"
            "hardwareDiagnostics"
            "laptop"
            "ollama"
            "ollamaFarm"
            "schedulerBenchmark"
            "screenRecording"
            "voxtype"
            "vr"
          ];
          invalidBooleanFeatures = builtins.filter
            (name: !(builtins.isBool resolvedFeatures.${name}))
            booleanFeatureNames;
          invalidPersonalApps = builtins.filter
            (name: !(builtins.isBool resolvedFeatures.personalApps.${name}))
            (builtins.attrNames defaultFeatures.personalApps);
          desktopFeatures = {
            amdGpu = resolvedFeatures.amdGpuMetrics;
            bluetooth = resolvedFeatures.bluetooth;
            docker = resolvedFeatures.docker;
            laptop = resolvedFeatures.laptop;
            ollama = resolvedFeatures.ollama;
            ollamaFarm = resolvedFeatures.ollamaFarm;
            personalApps = resolvedFeatures.personalApps;
            screenRecording = resolvedFeatures.screenRecording;
            voxtype = resolvedFeatures.voxtype;
          };
        in
        if !builtins.pathExists homeModule then
          throw "Host '${flakeHostName}' wskazuje brakujący profil Home Managera: home/${homeProfile}"
        else if !builtins.pathExists themeModule then
          throw "Wspólny profil Home Managera nie zawiera wymaganego pliku home/base/theme.nix"
        else if homeOverlay != null && !builtins.pathExists overlayModule then
          throw "Host '${flakeHostName}' wskazuje brakującą nakładkę: home/individual/${homeOverlay}/override.nix"
        else if unknownFeatures != [ ] then
          throw "Host '${flakeHostName}' ma nieznane pola features: ${builtins.concatStringsSep ", " unknownFeatures}"
        else if !builtins.isAttrs providedPersonalApps then
          throw "Host '${flakeHostName}' musi ustawić features.personalApps jako zestaw atrybutów"
        else if unknownPersonalApps != [ ] then
          throw "Host '${flakeHostName}' ma nieznane pola features.personalApps: ${builtins.concatStringsSep ", " unknownPersonalApps}"
        else if invalidBooleanFeatures != [ ] then
          throw "Host '${flakeHostName}' musi ustawić pola features jako true albo false: ${builtins.concatStringsSep ", " invalidBooleanFeatures}"
        else if invalidPersonalApps != [ ] then
          throw "Host '${flakeHostName}' musi ustawić pola features.personalApps jako true albo false: ${builtins.concatStringsSep ", " invalidPersonalApps}"
        else if !builtins.isAttrs providedHostModules then
          throw "Host '${flakeHostName}' musi ustawić modules jako zestaw atrybutów"
        else if unknownHostModules != [ ] then
          throw "Host '${flakeHostName}' ma nieznane pola modules: ${builtins.concatStringsSep ", " unknownHostModules}"
        else if invalidHostModules != [ ] then
          throw "Host '${flakeHostName}' musi ustawić pola modules jako true albo false: ${builtins.concatStringsSep ", " invalidHostModules}"
        else if resolvedFeatures.laptop && backlightDevice == null then
          throw "Host '${flakeHostName}' jest laptopem, ale nie ustawia backlightDevice"
        else if resolvedFeatures.ollama && !resolvedFeatures.docker then
          throw "Host '${flakeHostName}' wymaga features.docker = true dla features.ollama"
        else if resolvedFeatures.ollamaFarm && !resolvedFeatures.ollama then
          throw "Host '${flakeHostName}' wymaga features.ollama = true dla features.ollamaFarm"
        else if resolvedHostModules.hardwareAsusLaptop && !resolvedHostModules.hardwareAmdGpu then
          throw "Host '${flakeHostName}' wymaga modules.hardwareAmdGpu = true dla modules.hardwareAsusLaptop"
        else if resolvedHostModules.x1e && system != "aarch64-linux" then
          throw "Host '${flakeHostName}' wymaga system = aarch64-linux dla modules.x1e"
        else
          nixpkgs.lib.nixosSystem {
            inherit system;
            specialArgs = {
              inherit desktopTheme hostName inputs resolvedHostModules systemSettings userDescription username;
            };
            modules =
              [
                configuration
                home-manager.nixosModules.home-manager
                {
                  home-manager = {
                    useGlobalPkgs = true;
                    useUserPackages = true;
                    backupFileExtension = "hm-backup";
                    sharedModules = [ ./home/ollama.nix ];
                    extraSpecialArgs = {
                      inherit backlightDevice desktopFeatures homeProfile inputs trackball uiScale username;
                      replayConfig = defaultReplayConfig // replayConfig;
                    };
                    users.${username} = {
                      imports = [ homeModule ]
                        ++ nixpkgs.lib.optionals (homeOverlay != null) [ overlayModule ];
                    };
                  };
                }
              ]
              ++ nixpkgs.lib.optionals resolvedFeatures.docker [ ./modules/docker.nix ]
              ++ nixpkgs.lib.optionals resolvedFeatures.gaming [ ./modules/gaming.nix ]
              ++ nixpkgs.lib.optionals resolvedFeatures.schedulerBenchmark [ ./modules/scheduler-benchmark.nix ]
              ++ nixpkgs.lib.optionals resolvedFeatures.screenRecording [ ./modules/screen-recording.nix ]
              ++ nixpkgs.lib.optionals resolvedFeatures.hardwareDiagnostics [ ./modules/hardware-diagnostics.nix ]
              ++ nixpkgs.lib.optionals resolvedFeatures.ollama [ ./modules/ollama.nix ]
              ++ nixpkgs.lib.optionals resolvedFeatures.vr [ ./modules/vr.nix ]
              ++ nixpkgs.lib.optionals resolvedFeatures.bluetooth [ ./modules/bluetooth.nix ]
              ++ nixpkgs.lib.optionals resolvedFeatures.voxtype [ ./modules/voxtype.nix ];
          };
    in
    {
      apps.${defaultSystem}.scheduler-benchmark = {
        type = "app";
        program = "${schedulerBenchmark}/bin/scheduler-benchmark";
      };

      nixosConfigurations =
        nixpkgs.lib.mapAttrs
          (name: _: mkHost name (import (./hosts + "/${name}")))
          hostDirectories;

      packages.${defaultSystem}.scheduler-benchmark = schedulerBenchmark;

      devShells.${defaultSystem}.default = pkgs.mkShellNoCC {
        packages = with pkgs; [
          codex
          git
          neovim
        ];
      };
    };
}
