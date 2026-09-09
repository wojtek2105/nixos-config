{ lib, resolvedFeatures, ... }:

{
  # Docker is an explicit dependency checked by flake.nix. Its module supplies
  # Compose and the docker group; the Home Manager shared module projects the
  # immutable Compose guidance into the enabled user's ~/Dev/Ollama directory.

  # The standalone ROG deployment exposes only Ollama's API. It has no
  # authentication, so restrict the network to trusted devices.
  networking.firewall.allowedTCPPorts =
    if resolvedFeatures.ollamaStandalone then [ 11434 ] else [ 3000 8080 11434 11435 ];
}
