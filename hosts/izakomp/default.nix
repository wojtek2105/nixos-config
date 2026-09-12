let
  host = builtins.fromJSON (builtins.readFile ./host.json);
in
{
  configuration = ./configuration.nix;
  inherit (host) backlightDevice features homeOverlay homeProfile hostName ollamaVulkanRenderNode piApiBaseUrl piModelName replayConfig searxngUrl system systemSettings trackball uiScale userDescription username;
  hostModules = host.modules;
}
