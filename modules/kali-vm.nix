{ pkgs, username, ... }:

let
  virtui-manager = pkgs.callPackage ../packages/virtui-manager.nix { };
in

{
  # Libvirt uses KVM on this AMD host; the generated hardware module already
  # loads kvm-amd, so no host-specific kernel setting belongs here.
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
    };
  };

  programs.virt-manager.enable = true;
  environment.systemPackages = [ virtui-manager ];

  # This grants the local desktop user access to libvirt without sudo. Keep
  # it scoped to a host capability: libvirt can administer every local VM.
  users.users.${username}.extraGroups = [ "libvirtd" ];
}
