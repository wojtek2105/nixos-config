{ pkgs, ... }:

{
  # ALVR provides the Linux SteamVR driver and dashboard. For Quest 2 over
  # USB-C this uses ALVR's native wired mode over ADB, not Meta Quest Link.
  programs.alvr = {
    enable = true;
    # Native wired mode forwards traffic through ADB and does not need LAN
    # ingress. Keep 9943/9944 closed unless wireless ALVR is enabled later.
    openFirewall = false;
  };

  # SteamVR is installed from the Steam library after activation. Enabling
  # Steam here keeps the VR capability usable on hosts without gaming.nix.
  programs.steam.enable = true;

  # WayVR replaces SteamVR's unreliable desktop capture on Wayland. It is an
  # on-demand overlay: the package is installed, but no process or service is
  # started automatically. Launch it manually after ALVR has connected to VR.
  environment.systemPackages = with pkgs; [
    android-tools
    wayvr
  ];
}
