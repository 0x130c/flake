{
  description = "Helix (master) packaged like nixpkgs — split unwrapped/wrapped so the Rust binary is grammar-independent and cacheable";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    helix-src = {
      url = "github:helix-editor/helix";
      flake = false;
    };
  };

  nixConfig = {
    extra-substituters = [ "https://0x130c.cachix.org" ];
    extra-trusted-public-keys = [
      "0x130c.cachix.org-1:9NDrCOUGIl96U0bl0LUzHUbqikz5q39jv5dUz6KVHP8="
    ];
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      helix-src,
      ...
    }:
    let
      lib = nixpkgs.lib;

      # The curated grammar set that CI builds and caches: one `[[grammar]].name`
      # per line in ./grammars-enabled.txt, with `# …` annotations ignored.
      enabledGrammars =
        let
          firstToken =
            l:
            let
              m = builtins.match "[[:space:]]*([^[:space:]#]+).*" l;
            in
            if m == null then "" else builtins.head m;
        in
        lib.filter (s: s != "") (
          map firstToken (lib.splitString "\n" (builtins.readFile ./grammars-enabled.txt))
        );

      overlay = final: _prev: {
        helix-unwrapped = final.callPackage ./pkgs/helix-unwrapped.nix { inherit helix-src; };
        helix = final.callPackage ./pkgs/helix.nix {
          inherit helix-src;
          # Default to the curated set; override with `_: true` for every grammar,
          # or any other predicate `grammar -> bool`.
          includeGrammarIf = g: builtins.elem g.name enabledGrammars;
        };
      };

      systems = with flake-utils.lib.system; [ x86_64-linux ];
    in
    flake-utils.lib.eachSystem systems (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ overlay ];
        };
      in
      {
        packages = {
          inherit (pkgs) helix helix-unwrapped;
          default = pkgs.helix;
        };

        formatter = pkgs.nixfmt;

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            cachix
            nixfmt
          ];
        };
      }
    )
    // {
      overlays.default = overlay;
    };
}
