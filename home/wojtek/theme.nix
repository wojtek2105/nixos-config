{ inputs }:

let
  colors = {
    background = "1A1515";
    surface = "2D2424";
    selection = "453636";
    muted = "725A5A";
    subtle = "9C8181";
    foreground = "DCC9BC";
    bright = "FFE9C7";
    red = "CF223E";
    orange = "F07342";
    yellow = "E39C45";
    olive = "959A6B";
    green = "768F80";
    violet = "756D94";
    blue = "614F76";
    magenta = "7B3D79";
    accent = "AE3F82";
  };
in
{
  name = "Biscuit de Mar Dark";

  fonts = {
    interface = "CommitMono Nerd Font Propo";
    monospace = "CommitMono Nerd Font Mono";
    sans = "Inter";
  };

  inherit colors;

  semantic = {
    panel = colors.surface;
    panelHover = colors.selection;
    border = colors.muted;
    active = colors.accent;
    info = colors.violet;
    success = colors.green;
    warning = colors.orange;
    thermal = colors.yellow;
    critical = colors.red;
  };

  wallpapers = [
    ./wallpapers/frieren-observatory.png
    ./wallpapers/night-ops.png
    ./wallpapers/devsecops-owl.png
    ./wallpapers/zero-trust-shrine.png
    ./wallpapers/dependency-labyrinth.png
    ./wallpapers/packet-rain-rooftop.png
    ./wallpapers/reproducible-build-forge.png
    ./wallpapers/secure-release-montage.png
    ./wallpapers/smoke-and-policy.png
    ./wallpapers/desert-chemistry-ci.png
    ./wallpapers/demon-proxy.png
    ./wallpapers/monster-hunter-firewall.png
    ./wallpapers/shadow-incident.png
    ./wallpapers/malware-devil-hunt.png
    ./wallpapers/edge-runner-deploy.png
    ./wallpapers/subway-red-team.png
    ./wallpapers/soc-after-midnight.png
    ./wallpapers/physical-red-team-heist.png
    ./wallpapers/container-harbor.png
    ./wallpapers/cold-aisle-ghost.png
    ./wallpapers/threat-hunter-archive.png
    ./wallpapers/incident-response-bunker.png
  ];
  gtkTheme = "biscuit-dark";
  gtkThemeSource = "${inputs.biscuit-gtk}/biscuit-dark";
  iconTheme = "papirus-biscuit-dark";
  iconThemeSource = "${inputs.biscuit-gtk}/papirus-biscuit-dark";
}
