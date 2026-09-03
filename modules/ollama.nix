{ ... }:

{
  # Docker is an explicit dependency checked by flake.nix. Its module supplies
  # Compose and the docker group; the Home Manager shared module projects the
  # immutable Compose guidance into the enabled user's ~/Dev/Ollama directory.

  # Compose publishes these ports to the LAN. Ollama and SearXNG themselves
  # have no access control, so enable this module only on a trusted network.
  networking.firewall.allowedTCPPorts = [ 3000 8080 11434 11435 ];
}
