{ inputs, lib, pkgs, username, ... }:

let
  voxtype = inputs.voxtype.packages.${pkgs.stdenv.hostPlatform.system}.vulkan;
  voxtypeOsdGtk4 = inputs.voxtype.packages.${pkgs.stdenv.hostPlatform.system}."osd-gtk4";
  defaultUserConfig = ./voxtype-default-config.toml;
  servicePath = lib.makeBinPath [
    pkgs.curl
    pkgs.wl-clipboard
    pkgs.wtype
    pkgs.which
    voxtype
    voxtypeOsdGtk4
  ];
  prepareModel = pkgs.writeShellScript "voxtype-prepare-large-v3" ''
    model_path="''${XDG_DATA_HOME:-$HOME/.local/share}/voxtype/models/ggml-large-v3.bin"

    # A complete large-v3 download is about 3.1 GB. A cancelled curl transfer
    # leaves a smaller file that Voxtype mistakes for a ready model, so remove
    # only that known-invalid partial file before asking its idempotent setup
    # command to resume normal provisioning.
    if [[ -e "$model_path" ]]; then
      model_size="$(${pkgs.coreutils}/bin/stat --format=%s "$model_path")"
      if [[ "$model_size" -lt 3000000000 ]]; then
        ${pkgs.coreutils}/bin/rm -- "$model_path"
      fi
    fi

    exec ${voxtype}/bin/voxtype setup --download --model large-v3
  '';
  seedUserConfig = pkgs.writeShellScript "voxtype-seed-user-config" ''
    config_directory="''${XDG_CONFIG_HOME:-$HOME/.config}/voxtype"
    config_file="$config_directory/config.toml"

    # Nix provides a polished first-run baseline, but a user-owned TUI config
    # must remain mutable and never be replaced by later NixOS activations.
    # Voxtype 0.7.5 cannot save its older short template in the TUI (upstream
    # #421). Migrate only that known form: `state_file` is mandatory in the
    # bundled full template and absent from the previous Nix-generated file.
    if [[ -e "$config_file" ]]; then
      ${pkgs.gnugrep}/bin/grep -q '^state_file[[:space:]]*=' "$config_file" && exit 0
      if [[ ! -e "$config_file.pre-full-template" ]]; then
        ${pkgs.coreutils}/bin/cp --preserve=mode \
          "$config_file" "$config_file.pre-full-template"
      fi
    fi

    ${pkgs.coreutils}/bin/mkdir -p "$config_directory"
    ${pkgs.coreutils}/bin/cp /etc/voxtype/config.toml "$config_file"
  '';
  voxtypeEnvironment = [
    "PATH=${servicePath}"
    # Keep the user journal useful without retaining routine transcription
    # progress. `warn` still records failures that need attention.
    "RUST_LOG=warn"
    # The user-owned TUI configuration is the runtime authority. Do not add
    # VOXTYPE_* overrides here: systemd environment variables silently win over
    # ~/.config/voxtype/config.toml and make `voxtype configure` appear broken.
  ];
in
{
  config = {
    # The optional built-in hotkey reads evdev directly. Grant this sensitive
    # group only on hosts that explicitly opt into Voxtype.
    users.users.${username}.extraGroups = [ "input" ];

    # Vulkan makes local Whisper inference practical on the AMD and Intel GPUs
    # expected by this flake. `large-v3` is the most accurate multilingual
    # Whisper model; its 3.1 GB file stays in each user's XDG data directory,
    # rather than being duplicated in the immutable system closure.
    environment.systemPackages = [
      voxtype
      # The Vulkan package includes only the OSD launcher. The separately
      # packaged GTK4 frontend below is what actually renders its waveform.
      voxtypeOsdGtk4
      pkgs.wl-clipboard
      pkgs.wtype
    ];

    # This complete start-up profile was saved through the Voxtype v1 TUI.
    # Later TUI changes stay user-owned and are not overwritten by activation.
    environment.etc."voxtype/config.toml".source = defaultUserConfig;

    systemd.user.services.voxtype = {
    description = "Voxtype local Polish voice dictation";
    after = [ "graphical-session.target" "pipewire.service" ];
    wants = [ "pipewire.service" ];
    partOf = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    # Keyboard injection needs the Wayland socket, so never start the
    # downloader or daemon from a text-only user session.
    unitConfig.ConditionEnvironment = "WAYLAND_DISPLAY";
    serviceConfig = {
      # Systemd user units do not inherit the profile PATH. Voxtype invokes
      # curl itself to obtain its model and then needs Wayland typing tools.
      Environment = voxtypeEnvironment;
      # `setup --download` is idempotent: it fetches large-v3 only when the
      # current user has not downloaded it yet, keeping model data out of Git.
      ExecStartPre = [
        seedUserConfig
        prepareModel
      ];
      # `large-v3` is a 3.1 GB first-run download. systemd's 90-second default
      # would kill a healthy connection and leave a partial model behind.
      TimeoutStartSec = "30min";
      ExecStart = "${voxtype}/bin/voxtype daemon";
      Restart = "on-failure";
      RestartSec = 2;
    };
    };

  };
}
