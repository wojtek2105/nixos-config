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

  # systemd 258 supplies Android uaccess rules. Only the ADB client is needed
  # for authorization, diagnostics and manual APK installation.
  environment.systemPackages = [ pkgs.android-tools ];
}
