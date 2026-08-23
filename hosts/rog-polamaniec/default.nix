{
  configuration = ./configuration.nix;

  desktopFeatures = {
    amdGpu = true;
    docker = true;
    gaming = true;
    laptop = true;
    personalApps = true;
  };

  replayConfig.captureSource = "eDP-2";
}
