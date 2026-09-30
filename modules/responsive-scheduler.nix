{ pkgs, ... }:

{
  services.scx = {
    enable = true;
    # Rust schedulers avoid the additional C scheduler closure. Bpfland favors
    # interactive tasks under CPU load and remains suitable for daily desktop
    # use; revisit LAVD after the SCX 1.1.3 freeze regression is resolved.
    # Upstream tracker: https://github.com/sched-ext/scx/issues/3750
    package = pkgs.scx.rustscheds;
    scheduler = "scx_bpfland";
  };
}
