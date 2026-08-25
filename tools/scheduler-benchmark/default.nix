{
  callPackage,
  coreutils,
  gamemode,
  git,
  gnugrep,
  gnused,
  lib,
  pciutils,
  procps,
  python3,
  scx,
  stress-ng,
  supertuxkart,
  systemd,
  util-linux,
  writeShellApplication,
  writeText,
}:

let
  scxLavd112 = callPackage ./scx-lavd-1.1.2.nix { };
  reporter = writeText "scheduler-benchmark-report.py" (
    builtins.readFile ./report.py
  );
  stkBenchmarkConfig = writeText "scheduler-benchmark-stk-config.xml" (
    builtins.readFile ./stk-benchmark-config.xml
  );
in
writeShellApplication {
  name = "scheduler-benchmark";

  runtimeInputs = [
    coreutils
    gamemode
    git
    gnugrep
    gnused
    pciutils
    procps
    python3
    # Keep this before the complete current package. The explicit PATH prefix
    # below makes scx_lavd 1.1.2 deterministic even if 1.1.3 is system-wide.
    scxLavd112
    scx.rustscheds
    stress-ng
    supertuxkart
    systemd
    util-linux
  ];

  text = ''
    export PATH=${scxLavd112}/bin:"$PATH"
    export SCHEDULER_BENCH_REPORTER=${reporter}
    export SCHEDULER_BENCH_STK_CONFIG=${stkBenchmarkConfig}
    ${builtins.readFile ./scheduler-benchmark.sh}
  '';

  meta = {
    description = "On-demand SCX desktop and SuperTuxKart replay benchmark harness";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "scheduler-benchmark";
  };
}
