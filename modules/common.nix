{ pkgs, ... }:

{
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  time.timeZone = "Europe/Warsaw";

  i18n.defaultLocale = "pl_PL.UTF-8";

  environment.systemPackages = with pkgs; [
    curl
    fd
    git
    jq
    ripgrep
  ];
}
