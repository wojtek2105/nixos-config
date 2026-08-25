{
  # Compatibility aggregate for hosts that want the complete development
  # stack. New manifests import development-core.nix and gate docker.nix with
  # `features.docker`, so disabling Docker also removes its packages.
  imports = [
    ./development-core.nix
    ./docker.nix
  ];
}
