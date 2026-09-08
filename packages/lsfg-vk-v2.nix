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
    # Upstream serves an uncompressed tar archive under the .tar.xz name.
    sha256 = "d8378b45d378150ea9aba803a0ba855d8ce91ad9b3366ee0eb2036b06b08380c";
  };

  # The release archive is a tar despite its filename.
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
