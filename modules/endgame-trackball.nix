{ pkgs, ... }:

{
  # Marshmellow UI uses Web Serial. These are the three USB identities used by
  # the Endgame Trackball for ZMK Studio, normal configuration/logging and
  # debug firmware respectively. Verify them with `lsusb` if the firmware
  # exposes a different identity after an update.
  services.udev.extraRules = ''
    ATTRS{idVendor}=="0011", ATTRS{idProduct}=="0006", MODE="0666", TAG+="uaccess", ENV{ID_MM_DEVICE_IGNORE}="1", ENV{ID_MM_PORT_IGNORE}="1"
    ATTRS{idVendor}=="0011", ATTRS{idProduct}=="0007", MODE="0666", TAG+="uaccess", ENV{ID_MM_DEVICE_IGNORE}="1", ENV{ID_MM_PORT_IGNORE}="1"
    ATTRS{idVendor}=="0011", ATTRS{idProduct}=="DEAD", MODE="0666", TAG+="uaccess", ENV{ID_MM_DEVICE_IGNORE}="1", ENV{ID_MM_PORT_IGNORE}="1"
  '';

  # Zen is Firefox-based and cannot provide the Web Serial API required by
  # Marshmellow UI. Google Chrome is installed on demand for this utility;
  # launch it with `marshmellow-ui` from the application launcher or terminal.
  environment.systemPackages = [
    pkgs.google-chrome
    (pkgs.writeShellApplication {
      name = "marshmellow-ui";
      runtimeInputs = [ pkgs.google-chrome ];
      text = ''
        exec google-chrome "https://efog.tech/marshmellow-ui/" "$@"
      '';
    })
  ];
}
