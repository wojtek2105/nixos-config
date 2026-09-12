{
  autoPatchelfHook,
  fetchurl,
  lib,
  libGL,
  makeWrapper,
  pkgsi686Linux,
  qt6,
  stdenv,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "lsfg-vk";
  version = "2.0.0";

  src = fetchurl {
    url = "https://builds.lsfg-vk.dev/lsfg-vk-2.0.0.tar.xz";
    # Upstream corrected the v2 archive's XZ compression after its release.
    sha256 = "sha256-CL2983OhEQIt+H2seqh+O1ZLuEH5YVUuPKhf6hK1qnQ=";
  };

  # tar auto-detects the archive compression instead of trusting its filename.
  unpackPhase = ''
    tar -xf "$src"
  '';

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    libGL
    qt6.qtbase
    qt6.qtdeclarative
    stdenv.cc.cc.lib
    pkgsi686Linux.stdenv.cc.cc.lib
  ];

  installPhase = ''
    runHook preInstall
    install -Dm755 bin/lsfg-vk-cli bin/lsfg-vk-ui -t "$out/bin"
    install -Dm644 lib/liblsfg-vk-layer.so lib/liblsfg-vk-layer.x86.so -t "$out/lib"
    install -Dm644 share/vulkan/implicit_layer.d/* -t "$out/share/vulkan/implicit_layer.d"
    install -Dm644 share/applications/* -t "$out/share/applications"
    install -Dm644 share/icons/hicolor/256x256/apps/* -t "$out/share/icons/hicolor/256x256/apps"
    runHook postInstall
  '';

  # The release includes both x86_64 and i686 Vulkan layers.
  dontStrip = true;

  meta = {
    description = "Lossless Scaling Frame Generation Vulkan layer and configuration UI";
    homepage = "https://lsfg-vk.dev";
    license = lib.licenses.cc-by-nc-40;
    platforms = [ "x86_64-linux" ];
    mainProgram = "lsfg-vk-ui";
  };
})
