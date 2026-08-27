{
  configuration = ./configuration.nix;

  username = "wojtek";
  userDescription = "White Monster";
  homeProfile = "wojtek";

  # Reuse the portable desktop profile, but omit every laptop-specific
  # integration. The generated hardware module remains unique to this PC.
  features = {
    amdGpuMetrics = true;
    docker = true;
    gaming = true;
    vr = true;
    screenRecording = true;
    hardwareDiagnostics = false;
    schedulerBenchmark = false;
    laptop = false;

    personalApps = {
      discord = true;
      easyeffects = true;
      plexamp = true;
    };
  };

  replayConfig.captureSource = "focused_monitor";
}
