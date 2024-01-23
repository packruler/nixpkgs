{ stdenv
, lib
, docbook-xsl-nons
, fetchurl
, glib
, gobject-introspection
, gtk-doc
, libgudev
, libpcap
, meson
, mesonEmulatorHook
, ninja
, pkg-config
, python3
, systemdMinimal
, usbutils
, vala
, which
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "umockdev";
  version = "0.17.18";

  outputs = [ "bin" "out" "dev" "devdoc" ];

  src = fetchurl {
    url = "https://github.com/martinpitt/umockdev/releases/download/${finalAttrs.version}/umockdev-${finalAttrs.version}.tar.xz";
    sha256 = "sha256-RmrT4McV5W9Q6mqWUWWCPQc6hBN6y4oeObZlc2SKmF8=";
  };

  patches = [
    # Hardcode absolute paths to libraries so that consumers
    # do not need to set LD_LIBRARY_PATH themselves.
    ./hardcode-paths.patch
  ];

  nativeBuildInputs = [
    docbook-xsl-nons
    gobject-introspection
    gtk-doc
    meson
    ninja
    pkg-config
    vala
  ] ++ lib.optionals (!stdenv.buildPlatform.canExecute stdenv.hostPlatform) [
    mesonEmulatorHook
  ];

  buildInputs = [
    glib
    systemdMinimal
    libpcap
  ];

  checkInputs = lib.optionals finalAttrs.passthru.withGudev [
    libgudev
  ];

  nativeCheckInputs = [
    python3
    systemdMinimal
    usbutils
    which
  ];

  strictDeps = true;

  mesonFlags = [
    "-Dgtk_doc=true"
  ];

  doCheck = true;

  postPatch = ''
    # Substitute the path to this derivation in the patch we apply.
    substituteInPlace src/umockdev-wrapper \
      --subst-var-by 'LIBDIR' "''${!outputLib}/lib"
  '';

  preCheck = ''
    # Our patch makes the path to the `LD_PRELOAD`ed library absolute.
    # When running tests, the library is not yet installed, though,
    # so we need to replace the absolute path with a local one during build.
    # We are using a symlink that will be overridden during installation.
    mkdir -p "$out/lib"
    ln -s "$PWD/libumockdev-preload.so.0" "$out/lib/libumockdev-preload.so.0"
  '';

  passthru = {
    # libgudev is needed for an optional test but it itself relies on umockdev for testing.
    withGudev = false;

    tests = {
      withGudev = finalAttrs.finalPackage.overrideAttrs (attrs: {
        passthru = attrs.passthru // {
          withGudev = true;
        };
      });
    };
  };

  meta = with lib; {
    homepage = "https://github.com/martinpitt/umockdev";
    changelog = "https://github.com/martinpitt/umockdev/releases/tag/${finalAttrs.version}";
    description = "Mock hardware devices for creating unit tests";
    license = licenses.lgpl21Plus;
    maintainers = with maintainers; [ flokli ];
    platforms = with platforms; linux;
  };
})
