{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/host-base.nix
  ];

  services.udev.extraHwdb = ''
    # Map the standard HID Keyboard Menu usage (0x65) to right Alt on Iza's
    # host only. Verify an unusual keyboard's event code with `wev` before
    # changing this: the usual key name is `Menu` / `KEY_MENU`.
    evdev:input:b0003v*
     KEYBOARD_KEY_70065=rightalt
    evdev:input:b0005v*
     KEYBOARD_KEY_70065=rightalt
    evdev:input:b0011v0001p0001*
     KEYBOARD_KEY_65=rightalt
  '';
}
