let
  host = builtins.fromJSON (builtins.readFile ./host.json);
in
{
  configuration = ./configuration.nix;
  inherit (host) backlightDevice features homeOverlay homeProfile hostName ollamaVulkanRenderNode piApiBaseUrl piModelName replayConfig system systemSettings trackball uiScale userDescription username;
  # The MCP client stays on this ROG; its endpoint comes from the host manifest.
  searxngUrl = host.searxngUrl or null;
  hostModules = host.modules;
}
