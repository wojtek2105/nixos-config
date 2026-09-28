let
  host = builtins.fromJSON (builtins.readFile ./host.json);
in
{
  configuration = ./configuration.nix;
  inherit (host) features homeOverlay homeProfile hostName system systemSettings uiScale userDescription username;
  hostModules = host.modules;
}
