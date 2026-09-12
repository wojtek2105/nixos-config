let
  host = builtins.fromJSON (builtins.readFile ./host.json);
in
{
  configuration = ./configuration.nix;
  keyboardOptions = host.keyboardOptions or "";
  piCompactionReserveTokens = host.piCompactionReserveTokens or 24576;
  piContextWindow = host.piContextWindow or 65536;
  inherit (host) backlightDevice features homeOverlay homeProfile hostName ollamaVulkanRenderNode piApiBaseUrl piModelName replayConfig searxngUrl system systemSettings trackball uiScale userDescription username;
  hostModules = host.modules;
}
