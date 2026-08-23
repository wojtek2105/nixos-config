{
  description = "Custom NixOS build";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
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
      mkLaptop = desktopBar: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs desktopBar;
        };
        modules = [
          ./hosts/laptop/configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "hm-backup";
              extraSpecialArgs = {
                inherit inputs desktopBar;
              };
              users.wojtek = import ./home/wojtek;
            };
          }
        ];
      };
    in
    {
      nixosConfigurations = {
        laptop = mkLaptop "ironbar";
        laptop-ironbar = mkLaptop "ironbar";
        laptop-waybar = mkLaptop "waybar";
      };
    };
}
