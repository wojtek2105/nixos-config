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
      defaultReplayConfig = {
        captureSource = "focused_monitor";
        fps = 60;
        seconds = 120;
        videoCodec = "hevc";
        videoBitrate = 25000;
        audioCodec = "opus";
      };
      hostDirectories =
        nixpkgs.lib.filterAttrs
          (name: type:
            type == "directory"
            && builtins.pathExists (./hosts + "/${name}/default.nix"))
          (builtins.readDir ./hosts);
      mkHost = hostName:
        {
          backlightDevice ? null,
          configuration,
          desktopFeatures ? { },
          homeProfile ? username,
          replayConfig ? { },
          userDescription ? username,
          username,
        }:
        let
          homeModule = ./home + "/${homeProfile}/default.nix";
        in
        if !builtins.pathExists homeModule then
          throw "Host '${hostName}' wskazuje brakujący profil Home Managera: home/${homeProfile}"
        else if (desktopFeatures.laptop or false) && backlightDevice == null then
          throw "Host '${hostName}' jest laptopem, ale nie ustawia backlightDevice"
        else
          nixpkgs.lib.nixosSystem {
            inherit system;
            specialArgs = {
              inherit inputs hostName userDescription username;
            };
            modules = [
              configuration
              home-manager.nixosModules.home-manager
              {
                home-manager = {
                  useGlobalPkgs = true;
                  useUserPackages = true;
                  backupFileExtension = "hm-backup";
                  extraSpecialArgs = {
                    inherit backlightDevice desktopFeatures inputs username;
                    replayConfig = defaultReplayConfig // replayConfig;
                  };
                  users.${username} = import homeModule;
                };
              }
            ];
          };
    in
    {
      nixosConfigurations =
        nixpkgs.lib.mapAttrs
          (name: _: mkHost name (import (./hosts + "/${name}")))
          hostDirectories;

      devShells.${system}.default = pkgs.mkShellNoCC {
        packages = with pkgs; [
          codex
          git
          neovim
        ];
      };
    };
}
