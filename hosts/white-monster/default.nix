let
  host = builtins.fromJSON (builtins.readFile ./host.json);
in
{
  configuration = ./configuration.nix;
  inherit (host) backlightDevice features homeOverlay homeProfile hostName replayConfig system systemSettings trackball uiScale userDescription username;
  hostModules = host.modules;
}
