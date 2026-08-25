{ pkgs, ... }:

{
  programs.fish.enable = true;

  environment.etc."codex/config.toml".text = ''
    [tui]
    notifications = true
    notification_method = "bel"
    notification_condition = "unfocused"
  '';

  environment.systemPackages = with pkgs; [
    codex
    gnumake
  ];
}
