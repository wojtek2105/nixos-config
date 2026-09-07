{ ... }:

{
  services.openssh = {
    enable = true;
    settings = {
      # Administracja odbywa się przez zwykłe konto; root loguje się tylko
      # lokalnie, a dostęp hasłem pozostaje dostępny na czas instalacji usług.
      PermitRootLogin = "no";
      PasswordAuthentication = true;
    };
  };

  networking.firewall.allowedTCPPorts = [ 22 ];
}
