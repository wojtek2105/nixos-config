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
        captureSource = "screen";
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
      mkHost =
        {
          configuration,
          desktopFeatures ? { },
          replayConfig ? { },
        }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [
            configuration
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "hm-backup";
                extraSpecialArgs = {
                  inherit inputs desktopFeatures;
                  replayConfig = defaultReplayConfig // replayConfig;
                };
                users.wojtek = import ./home/wojtek;
              };
            }
          ];
        };
    in
    {
      nixosConfigurations =
        nixpkgs.lib.mapAttrs
          (name: _: mkHost (import (./hosts + "/${name}")))
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
