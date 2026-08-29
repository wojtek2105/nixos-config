{ lib, pkgs, ... }:

{
  # ALVR provides the Linux SteamVR driver and dashboard. For Quest 2 over
  # USB-C this uses ALVR's native wired mode over ADB, not Meta Quest Link.
  programs.alvr = {
    enable = true;
    package = pkgs.symlinkJoin {
      name = "${pkgs.alvr.name}-with-adb";
      paths = [ pkgs.alvr ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        # Wired mode runs inside SteamVR's driver process, where the host PATH
        # is not reliable. ALVR checks this installation-relative fallback
        # before attempting to download platform-tools into the read-only store.
        mkdir -p "$out/bin/platform-tools"
        ln -s ${pkgs.android-tools}/bin/adb "$out/bin/platform-tools/adb"

        # Keep the wrapped executable inside this output. ALVR derives the
        # SteamVR driver root from its own executable path; wrapping the
        # original store path would register the unmodified package instead.
        rm "$out/bin/alvr_dashboard"
        cp ${pkgs.alvr}/bin/alvr_dashboard "$out/bin/alvr_dashboard"
        chmod +w "$out/bin/alvr_dashboard"
        wrapProgram "$out/bin/alvr_dashboard" \
          --prefix PATH : ${lib.makeBinPath [ pkgs.android-tools ]}
      '';
    };
    # Wireless ALVR discovery and streaming use TCP/UDP 9943-9944. Keep this
    # enabled while Wi-Fi is an intended fallback for the native wired mode.
    openFirewall = true;
  };

  # SteamVR is installed from the Steam library after activation. Enabling
  # Steam here keeps the VR capability usable on hosts without gaming.nix.
  programs.steam = {
    enable = true;
    # The ALVR driver runs inside Steam's isolated environment. Expose ADB
    # there so wired mode uses the packaged binary instead of trying to
    # download platform-tools into the read-only Nix store. SteamVR's
    # vrwebhelper also needs libatk-bridge to render settings and Home panels.
    extraPackages = [
      pkgs.android-tools
      pkgs.at-spi2-core
    ];
  };

  # WayVR replaces SteamVR's unreliable desktop capture on Wayland. It is an
  # on-demand overlay: the package is installed, but no process or service is
  # started automatically. Launch it manually after ALVR has connected to VR.
  # systemd 258 supplies Android uaccess rules. Only the ADB client is needed
  # for authorization, diagnostics and manual APK installation.
  environment.systemPackages = [
    pkgs.android-tools
    pkgs.wayvr
    (pkgs.writeShellScriptBin "steamvr-home" ''
      # SteamVR Home's launcher is built for a conventional FHS filesystem.
      # steam-run supplies that environment on NixOS.
      if ! ${pkgs.procps}/bin/pgrep -x vrserver >/dev/null; then
        ${pkgs.steam}/bin/steam -applaunch 250820 -pipewire >/dev/null 2>&1 &

        # SteamVR needs a moment to bring up vrserver and vrcompositor before
        # Home can register itself as the active VR scene.
        for _ in $(${pkgs.coreutils}/bin/seq 1 30); do
          ${pkgs.procps}/bin/pgrep -x vrserver >/dev/null && break
          ${pkgs.coreutils}/bin/sleep 1
        done
      fi

      if ! ${pkgs.procps}/bin/pgrep -x vrserver >/dev/null; then
        echo "SteamVR did not start within 30 seconds." >&2
        exit 1
      fi

      exec ${pkgs.steam-run}/bin/steam-run \
        /home/wojtek/.local/share/Steam/steamapps/common/SteamVR/tools/steamvr_environments/game/steamtours.sh \
        -vr -retail -vulkan -useappid SteamVRAppID -nowindow
    '')
    (pkgs.writeShellScriptBin "phasmophobia-vr" ''
      # SteamVR needs this backend selected before the game creates its VR
      # session. Proton's VR opt-in stays scoped to Phasmophobia so ordinary
      # non-VR Proton games retain their standard environment.
      if ! ${pkgs.procps}/bin/pgrep -x vrserver >/dev/null; then
        ${pkgs.steam}/bin/steam -applaunch 250820 -pipewire >/dev/null 2>&1 &

        for _ in $(${pkgs.coreutils}/bin/seq 1 30); do
          ${pkgs.procps}/bin/pgrep -x vrserver >/dev/null && break
          ${pkgs.coreutils}/bin/sleep 1
        done
      fi

      if ! ${pkgs.procps}/bin/pgrep -x vrserver >/dev/null; then
        echo "SteamVR did not start with PipeWire within 30 seconds." >&2
        exit 1
      fi

      export PROTON_ENABLE_VR=1
      exec ${pkgs.steam}/bin/steam -applaunch 739630
    '')
  ];
}
