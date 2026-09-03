{
  # Kept outside the desktop baseline so hosts without an adapter do not start
  # BlueZ or power a radio merely because they share the graphical session.
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
}
