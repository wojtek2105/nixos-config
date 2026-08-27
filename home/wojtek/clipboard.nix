{ pkgs, ... }:

let
  # Keep wl-clipboard as the system-wide provider used by screenshots and
  # scripts; Stash's compatibility symlinks would otherwise collide with it.
  stashPackage = pkgs.stash-clipboard.override { createSymlinks = false; };

  clipboard-history = pkgs.writeShellApplication {
    name = "clipboard-history";
    runtimeInputs = with pkgs; [
      fuzzel
      stashPackage
      wl-clipboard
      wtype
    ];
    text = ''
      chosen="$(
        stash list --format tsv \
          | fuzzel \
              --dmenu \
              --cache=/dev/null \
              --with-nth 2 \
              --prompt 'Schowek: '
      )" || exit 0
      [[ -n "$chosen" ]] || exit 0

      entry_id="''${chosen%%$'\t'*}"
      [[ "$entry_id" =~ ^[0-9]+$ ]] || exit 1

      stash decode "$entry_id" | wl-copy
      sleep 0.1
      wtype -M ctrl -k v -m ctrl
    '';
  };
in
{
  home.packages = [
    clipboard-history
    stashPackage
  ];

  systemd.user.services.stash-clipboard = {
    Unit = {
      Description = "Rust Wayland clipboard history";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };
    Service = {
      # Retain large screenshots without allowing an unbounded multimedia
      # database: at most 200 entries, 30 MiB each and 30 days of history.
      ExecStart = "${stashPackage}/bin/stash --max-items 200 --max-size 31457280 --max-dedupe-search 100 watch --mime-type image --expire-after 30d";
      Restart = "on-failure";
      RestartSec = 1;
      # The native watcher also honors password-manager sensitivity hints.
      Environment = [ "STASH_EXCLUDED_APPS=Bitwarden" ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
