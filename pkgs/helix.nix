# Helix master, wrapped: the grammar-independent binary from ./helix-unwrapped.nix
# plus a runtime directory carrying the tree-sitter grammars and their queries.
#
# Grammars are built by *upstream's own* grammars.nix (read straight from master's
# languages.toml), so they always match the checked-out source and we never have to
# regenerate a grammars.json / run nurl. `includeGrammarIf` is forwarded so a
# consumer can trim the set with `.override`; doing so only rebuilds grammars +
# this thin wrapper — helix-unwrapped stays a cache hit.
{
  lib,
  symlinkJoin,
  runCommand,
  makeBinaryWrapper,
  callPackage,
  helix-unwrapped,
  helix-src,
  # Predicate `grammar -> bool`; `grammar` is an attrset with `.name` (and `.source`).
  # e.g. includeGrammarIf = g: builtins.elem g.name [ "rust" "nix" "python" ];
  includeGrammarIf ? (_: true),
  grammarOverlays ? [ ],
}:
let
  grammars = callPackage "${helix-src}/grammars.nix" {
    inherit includeGrammarIf grammarOverlays;
  };

  # HELIX_RUNTIME layer: grammars + matching queries from the same master source.
  # Themes/tutor come from helix-unwrapped's HELIX_DEFAULT_RUNTIME; Helix merges both.
  runtimeDir = runCommand "helix-runtime" { } ''
    mkdir -p $out
    ln -s ${grammars} $out/grammars
    cp -r --no-preserve=mode ${helix-src}/runtime/queries $out/queries
  '';
in
symlinkJoin {
  name = "helix-${helix-unwrapped.version}";

  paths = [ helix-unwrapped ];
  nativeBuildInputs = [ makeBinaryWrapper ];

  postBuild = ''
    wrapProgram $out/bin/hx --set HELIX_RUNTIME "${runtimeDir}"
  '';

  passthru = {
    inherit helix-unwrapped grammars runtimeDir;
    inherit (helix-unwrapped) version;
  };

  meta = helix-unwrapped.meta // {
    description = "Post-modern modal text editor (master)";
  };
}
