{
  fetchFromGitHub,
  runCommand,
  rustPlatform,
  scx,
}:

let
  version = "1.1.2";
  source = fetchFromGitHub {
    owner = "sched-ext";
    repo = "scx";
    tag = "v${version}";
    hash = "sha256-igrmrfimVOEJnFxMr9ghN6lAHwEBSFLLVrB2MQ72PXI=";
  };
  vendorHash = "sha256-CTEVdvw6aG/fFas2Fk3x9o4Sp2k3lHO/OLwUM8t9UjE=";

  # LAVD 1.1.3 has a reported gaming freeze/stall regression. Keep the
  # downgrade local to the on-demand benchmark so the installed bpfland and
  # the other comparison candidates continue to follow the locked nixpkgs.
  scxRustscheds112 = scx.rustscheds.overrideAttrs (previousAttrs: {
    inherit version;

    src = source;
    cargoHash = vendorHash;
    # buildRustPackage materializes cargoDeps before overrideAttrs is applied.
    # Replace that derivation explicitly; changing cargoHash alone would keep
    # the 1.1.3 vendor hash and fail before compilation.
    cargoDeps = rustPlatform.fetchCargoVendor {
      src = source;
      hash = vendorHash;
    };

    # The install check in the current package derives its expected binaries
    # from passthru. Version 1.1.2 predates scx_mlfq, so retain its exact list.
    passthru = previousAttrs.passthru // {
      schedulers = [
        "scx_beerland"
        "scx_bpfland"
        "scx_cake"
        "scx_chaos"
        "scx_characterize"
        "scx_cosmos"
        "scx_flash"
        "scx_flow"
        "scx_forge"
        "scx_lavd"
        "scx_layered"
        "scx_mitosis"
        "scx_p2dq"
        "scx_pandemonium"
        "scx_rlfifo"
        "scx_rustland"
        "scx_rusty"
        "scx_tickless"
      ];
    };
  });
in
runCommand "scx-lavd-${version}"
  {
    meta = scxRustscheds112.meta // {
      description = "scx_lavd 1.1.2 isolated for scheduler regression benchmarks";
      mainProgram = "scx_lavd";
    };
    passthru = {
      inherit version;
      upstreamPackage = scxRustscheds112;
    };
  }
  ''
    mkdir -p "$out/bin"
    install -m 0755 ${scxRustscheds112}/bin/scx_lavd "$out/bin/scx_lavd"
  ''
