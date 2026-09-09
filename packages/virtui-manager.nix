{
  fetchFromGitHub,
  gobject-introspection,
  lib,
  libosinfo,
  libvirt,
  makeWrapper,
  osinfo-db,
  python3Packages,
  qemu,
  virt-viewer,
}:

python3Packages.buildPythonApplication (finalAttrs: {
  pname = "virtui-manager";
  version = "3.3.2";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "aginies";
    repo = "virtui-manager";
    tag = "v${finalAttrs.version}";
    hash = "sha256-xNX42Uwrr/lTCVui3GP7CP5FOJ3u1zEpOfTZfRdiM58=";
  };

  build-system = with python3Packages; [ setuptools wheel ];
  dependencies = with python3Packages; [
    libvirt-python
    textual
    pyyaml
    markdown-it-py
    packaging
    requests
    netifaces
    pygobject3
  ];

  nativeBuildInputs = [ makeWrapper ];

  # Upstream assumes a FHS host. Keep its embedded Virsh shell usable on NixOS.
  postPatch = ''
    substituteInPlace src/vmanager/modals/virsh_modals.py \
      --replace-fail /usr/bin/virsh ${libvirt}/bin/virsh
  '';

  # VM creation queries the OS database; console, disk tools and libvirt's CLI
  # need stable paths because NixOS does not provide a global /usr/bin.
  postFixup = ''
    wrapProgram $out/bin/virtui-manager \
      --prefix PATH : ${lib.makeBinPath [ libosinfo libvirt osinfo-db qemu virt-viewer ]} \
      --prefix GI_TYPELIB_PATH : ${lib.makeSearchPath "lib/girepository-1.0" [ libosinfo gobject-introspection ]}
  '';

  pythonImportsCheck = [ "vmanager" ];

  meta = {
    description = "Terminal user interface for libvirt virtual machines";
    homepage = "https://github.com/aginies/virtui-manager";
    license = lib.licenses.gpl3Plus;
    mainProgram = "virtui-manager";
    platforms = lib.platforms.linux;
  };
})
