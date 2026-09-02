{ pkgs, ... }:

{
  imports = [
    ./voxtype.nix
  ];

  nix = {
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];

    # Treat declarative builds as background work. Interactive applications
    # keep lower CPU and storage latency while a rebuild is running, at the
    # cost of a potentially longer build whenever the machine is busy.
    daemonCPUSchedPolicy = "idle";
    daemonIOSchedClass = "idle";
  };

  time.timeZone = "Europe/Warsaw";

  i18n.defaultLocale = "pl_PL.UTF-8";

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    # This is compressed swap capacity relative to physical RAM, not a fixed
    # reservation. It scales across hosts and allocates real memory on demand.
    memoryPercent = 50;
  };

  boot.kernel.sysctl = {
    # ZRAM is memory-backed, so it should not inherit the disk-swap read-ahead
    # of eight pages. Reading only the requested page avoids needless work.
    "vm.page-cluster" = 0;
    # A neutral 100 lets the kernel compare reclaiming file cache with moving
    # anonymous pages to ZRAM without the aggressive swapping caused by 180+.
    "vm.swappiness" = 100;
  };

  environment.systemPackages = with pkgs; [
    curl
    fd
    git
    jq
    ripgrep
  ];
}
