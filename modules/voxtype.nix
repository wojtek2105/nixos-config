{ lib, pkgs, ... }:

let
  voxtype = pkgs.voxtype-vulkan;
  servicePath = lib.makeBinPath [
    pkgs.curl
    pkgs.wl-clipboard
    pkgs.wtype
    voxtype
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
    [[ -e "$config_file" ]] && exit 0

    ${pkgs.coreutils}/bin/mkdir -p "$config_directory"
    ${pkgs.coreutils}/bin/cp /etc/voxtype/config.toml "$config_file"
  '';
  voxtypeEnvironment = [
    "PATH=${servicePath}"
    # The user-owned TUI configuration is the runtime authority. Do not add
    # VOXTYPE_* overrides here: systemd environment variables silently win over
    # ~/.config/voxtype/config.toml and make `voxtype configure` appear broken.
  ];
in
{
  config = {
    # Vulkan makes local Whisper inference practical on the AMD and Intel GPUs
    # expected by this flake. `large-v3` is the most accurate multilingual
    # Whisper model; its 3.1 GB file stays in each user's XDG data directory,
    # rather than being duplicated in the immutable system closure.
    environment.systemPackages = [
      voxtype
      pkgs.wl-clipboard
      pkgs.wtype
    ];

    # This is copied once to a new user's config directory before Voxtype
    # starts. Later changes through `voxtype configure` stay user-owned.
    environment.etc."voxtype/config.toml".text = ''
    engine = "whisper"

    [audio]
    # PipeWire selects the user's current default microphone, so this works
    # across hosts without encoding an ALSA or PulseAudio device name.
    device = "default"
    sample_rate = 16000
    max_duration_secs = 120

    [whisper]
    backend = "local"
    model = "large-v3"
    language = "pl"
    translate = false
    # Technical, DevOps and gaming vocabulary bias; keep this a compact list
    # of names so ordinary Polish speech stays natural.
    initial_prompt = "Polskie dyktowanie techniczne: NixOS, Nix, flakes, Home Manager, Hyprland, systemd, Docker, Kubernetes, Terraform, Ansible, GitHub Actions, CI/CD, Linux, Bash, Rust, Python, TypeScript, JavaScript, PostgreSQL, Redis, API, CLI, GPU, Vulkan, Steam, Discord, Valheim."
    # Loading only for a dictation releases the large model's RAM/VRAM between
    # uses. This is the safe portable default for laptop and gaming hosts.
    on_demand_loading = true

    [hotkey]
    # The user chooses and enables Voxtype's built-in hotkey in its TUI. Keep
    # the system fallback disabled so headless hosts never claim evdev access.
    enabled = false
    mode = "toggle"

    [output]
    mode = "type"
    # Hyprland is wlroots-based, so wtype preserves Polish Unicode directly.
    # Clipboard remains a safe fallback for a focused application that rejects
    # virtual keyboard input.
    driver_order = ["wtype", "clipboard"]

    [text]
    spoken_punctuation = true
    '';

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
