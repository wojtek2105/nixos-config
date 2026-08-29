{
  description = "Custom NixOS build";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
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
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
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
        docker = false;
        gaming = false;
        hardwareDiagnostics = false;
        laptop = false;
        schedulerBenchmark = false;
        vr = false;
        personalApps = {
          discord = false;
          easyeffects = false;
          plexamp = false;
        };
        screenRecording = false;
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
      mkHost = hostName:
        {
          backlightDevice ? null,
          configuration,
          features ? { },
          homeProfile ? username,
          replayConfig ? { },
          uiScale ? 2,
          userDescription ? username,
          username,
        }:
        let
          homeModule = ./home + "/${homeProfile}/default.nix";
          themeModule = ./home + "/${homeProfile}/theme.nix";
          desktopTheme = import themeModule { inherit inputs; };
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
            "docker"
            "gaming"
            "hardwareDiagnostics"
            "laptop"
            "schedulerBenchmark"
            "screenRecording"
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
            docker = resolvedFeatures.docker;
            laptop = resolvedFeatures.laptop;
            personalApps = resolvedFeatures.personalApps;
            screenRecording = resolvedFeatures.screenRecording;
          };
        in
        if !builtins.pathExists homeModule then
          throw "Host '${hostName}' wskazuje brakujący profil Home Managera: home/${homeProfile}"
        else if !builtins.pathExists themeModule then
          throw "Profil '${homeProfile}' nie zawiera wymaganego pliku theme.nix"
        else if unknownFeatures != [ ] then
          throw "Host '${hostName}' ma nieznane pola features: ${builtins.concatStringsSep ", " unknownFeatures}"
        else if !builtins.isAttrs providedPersonalApps then
          throw "Host '${hostName}' musi ustawić features.personalApps jako zestaw atrybutów"
        else if unknownPersonalApps != [ ] then
          throw "Host '${hostName}' ma nieznane pola features.personalApps: ${builtins.concatStringsSep ", " unknownPersonalApps}"
        else if invalidBooleanFeatures != [ ] then
          throw "Host '${hostName}' musi ustawić pola features jako true albo false: ${builtins.concatStringsSep ", " invalidBooleanFeatures}"
        else if invalidPersonalApps != [ ] then
          throw "Host '${hostName}' musi ustawić pola features.personalApps jako true albo false: ${builtins.concatStringsSep ", " invalidPersonalApps}"
        else if resolvedFeatures.laptop && backlightDevice == null then
          throw "Host '${hostName}' jest laptopem, ale nie ustawia backlightDevice"
        else
          nixpkgs.lib.nixosSystem {
            inherit system;
            specialArgs = {
              inherit desktopTheme inputs hostName userDescription username;
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
                    extraSpecialArgs = {
                      inherit backlightDevice desktopFeatures inputs uiScale username;
                      replayConfig = defaultReplayConfig // replayConfig;
                    };
                    users.${username} = import homeModule;
                  };
                }
              ]
              ++ nixpkgs.lib.optionals resolvedFeatures.docker [ ./modules/docker.nix ]
              ++ nixpkgs.lib.optionals resolvedFeatures.gaming [ ./modules/gaming.nix ]
              ++ nixpkgs.lib.optionals resolvedFeatures.schedulerBenchmark [ ./modules/scheduler-benchmark.nix ]
              ++ nixpkgs.lib.optionals resolvedFeatures.screenRecording [ ./modules/screen-recording.nix ]
              ++ nixpkgs.lib.optionals resolvedFeatures.hardwareDiagnostics [ ./modules/hardware-diagnostics.nix ]
              ++ nixpkgs.lib.optionals resolvedFeatures.vr [ ./modules/vr.nix ];
          };
    in
    {
      apps.${system}.scheduler-benchmark = {
        type = "app";
        program = "${schedulerBenchmark}/bin/scheduler-benchmark";
      };

      nixosConfigurations =
        nixpkgs.lib.mapAttrs
          (name: _: mkHost name (import (./hosts + "/${name}")))
          hostDirectories;

      packages.${system}.scheduler-benchmark = schedulerBenchmark;

      devShells.${system}.default = pkgs.mkShellNoCC {
        packages = with pkgs; [
          codex
          git
          neovim
        ];
      };
    };
}
