let
  host = builtins.fromJSON (builtins.readFile ./host.json);
in
{
  configuration = ./configuration.nix;
  inherit (host) backlightDevice features homeOverlay homeProfile hostName ollamaVulkanRenderNode piApiBaseUrl piModelName replayConfig system systemSettings trackball uiScale userDescription username;
  # SearXNG runs on White Monster; the MCP client itself stays on this ROG.
  searxngUrl = host.searxngUrl or null;
  hostModules = host.modules;
}
