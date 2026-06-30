# Helix master, packaged nixpkgs-style: just the Rust binary.
#
# Crucially this derivation is *grammar-independent* — the runtime baked in via
# HELIX_DEFAULT_RUNTIME has `grammars` and `queries` stripped out. That keeps the
# (expensive to compile) binary identical no matter which grammar set the wrapper
# in ./helix.nix ends up selecting, so it can be built once and pulled from the
# binary cache even when a consumer overrides `includeGrammarIf`.
{
  lib,
  rustPlatform,
  installShellFiles,
  runCommand,
  helix-src,
}:
let
  rev = helix-src.rev or "0000000000000000000000000000000000000000";
  date = helix-src.lastModifiedDate or "19700101000000";
  dateStr = lib.concatStringsSep "-" [
    (builtins.substring 0 4 date)
    (builtins.substring 4 2 date)
    (builtins.substring 6 2 date)
  ];
  workspaceVersion =
    (builtins.fromTOML (builtins.readFile "${helix-src}/Cargo.toml")).workspace.package.version;

  # Everything in runtime/ except grammars and queries — those are layered back
  # on at runtime by the wrapper via HELIX_RUNTIME so they can vary freely.
  defaultRuntimeDir = runCommand "helix-default-runtime" { } ''
    cp -r --no-preserve=mode ${helix-src}/runtime $out
    rm -rf $out/grammars $out/queries
  '';
in
rustPlatform.buildRustPackage {
  pname = "helix-unwrapped";
  version = "${workspaceVersion}-unstable-${dateStr}";

  src = helix-src;

  cargoLock = {
    lockFile = "${helix-src}/Cargo.lock";
    # Not allowed in nixpkgs, but convenient: lets any temporary git dependency in
    # master's Cargo.lock resolve without us maintaining `outputHashes` here.
    allowBuiltinFetchGit = true;
  };

  nativeBuildInputs = [ installShellFiles ];

  buildType = "release";
  doCheck = false;
  strictDeps = true;

  env = {
    # Disable build.rs fetching/compiling tree-sitter grammars; the wrapper owns them.
    HELIX_DISABLE_AUTO_GRAMMAR_BUILD = "1";
    HELIX_DEFAULT_RUNTIME = "${defaultRuntimeDir}";
    # So `hx --version` reports the master rev it was built from.
    HELIX_NIX_BUILD_REV = rev;
  };

  postInstall = ''
    installShellCompletion ${helix-src}/contrib/completion/hx.{bash,fish,zsh}
    mkdir -p $out/share/{applications,icons/hicolor/{256x256,scalable}/apps}
    cp ${helix-src}/contrib/Helix.desktop $out/share/applications/Helix.desktop
    cp ${helix-src}/logo.svg $out/share/icons/hicolor/scalable/apps/helix.svg
    cp ${helix-src}/contrib/helix.png $out/share/icons/hicolor/256x256/apps/helix.png
  '';

  meta = {
    description = "Post-modern modal text editor (master, unwrapped — no grammars)";
    homepage = "https://helix-editor.com";
    changelog = "https://github.com/helix-editor/helix/blob/${rev}/CHANGELOG.md";
    license = lib.licenses.mpl20;
    mainProgram = "hx";
    platforms = lib.platforms.linux;
  };
}
