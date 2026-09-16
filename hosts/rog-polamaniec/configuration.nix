{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/host-base.nix
  ];

  # Obejście awarii DMUB auto-load na Radeon 680M z firmware 20260910.
  # Cofamy tylko DMCUB DCN 3.1.2; pozostałe firmware zachowują bieżące wersje.
  # Zmiana obejmuje initrd i wymaga restartu. Usunąć po potwierdzeniu poprawki upstream.
  nixpkgs.overlays = [
    (final: prev: {
      linux-firmware = prev.linux-firmware.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          cp ${final.fetchFromGitLab {
            owner = "kernel-firmware";
            repo = "linux-firmware";
            tag = "20260810";
            hash = "sha256-P/fPpqaatp8Z2GV+I/OChiWGn6AhV+8w1RMFuX/LqHc=";
          }}/amdgpu/yellow_carp_dmcub.bin amdgpu/yellow_carp_dmcub.bin
        '';
      });
    })
  ];
}
