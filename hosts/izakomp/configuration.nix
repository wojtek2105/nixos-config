{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/host-base.nix
  ];

  # Menu działa jako AltGr (trzeci poziom) dla polskich znaków w układzie `pl`.
  xserver.xkb.options = "lv3:menu_switch";
}
