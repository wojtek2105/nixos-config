{ keyboardOptions, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/host-base.nix
  ];

  # Menu działa jako AltGr (trzeci poziom) dla polskich znaków w układzie `pl`.
  services.xserver.xkb.options = keyboardOptions;
}
