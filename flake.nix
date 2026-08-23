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
      nixosConfigurations = {
        rog-polamaniec = mkHost {
          configuration = ./hosts/rog-polamaniec/configuration.nix;
          desktopFeatures = {
            amdGpu = true;
            docker = true;
            gaming = true;
            laptop = true;
            personalApps = true;
          };
          replayConfig.captureSource = "eDP-2";
        };
      };

      nixosModules.simple = ./hosts/simple/configuration.nix;

      devShells.${system}.default = pkgs.mkShellNoCC {
        packages = with pkgs; [
          codex
          git
          neovim
        ];
      };
    };
}
