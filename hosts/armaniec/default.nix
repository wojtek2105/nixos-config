{
  configuration = ./configuration.nix;

  # Snapdragon X is ARM64; each host chooses its own platform so existing
  # x86_64 hosts and their package closures stay unchanged.
  system = "aarch64-linux";

  username = "wojtek";
  userDescription = "Wojtek";
  # Reuse the full desktop session: Ironbar, Hyprland, notifications, OSD,
  # clipboard and user tools remain native aarch64 packages when available.
  homeProfile = "wojtek";

  # Vivobook S 15 has a high-density internal display. Adjust after checking
  # the usable scale in Hyprland; 1 keeps this initial recovery-oriented setup
  # readable on external displays too.
  uiScale = 1;

  # First boot contains the portable desktop baseline plus native Zen and Codex.
  # It omits gaming, AMD/ROG controls, replay capture, Docker and personal
  # optional applications until hardware support is verified.
  features = {
    amdGpuMetrics = false;
    docker = false;
    gaming = false;
    hardwareDiagnostics = false;
    laptop = false;
    schedulerBenchmark = false;
    screenRecording = false;
    vr = false;

    personalApps = {
      discord = false;
      easyeffects = false;
      plexamp = false;
    };
  };
}
