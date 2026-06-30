# 0x130c/flake — Helix (master), nixpkgs-style

Tracks **helix master** but packages it the way nixpkgs does: split into a
grammar-independent Rust binary (`helix-unwrapped`) and a thin wrapper (`helix`)
that layers in the tree-sitter grammars at runtime.

Why: the wrapper's grammar set can change (or be trimmed) **without** rebuilding the
expensive Rust binary, so the binary is built once by CI and pulled from the
[`0x130c`](https://app.cachix.org/cache/0x130c) cachix cache — even when you override
the grammar set.

- `helix-unwrapped` — the `hx` binary, `HELIX_DEFAULT_RUNTIME` with `grammars`/`queries`
  stripped. Grammar-independent ⇒ always a cache hit.
- `helix` — `helix-unwrapped` + a `HELIX_RUNTIME` carrying grammars (built by upstream's
  own `grammars.nix` from master's `languages.toml`) and matching queries.

## Use

```nix
{
  inputs.helix.url = "github:0x130c/flake";

  # in a module / overlay:
  # pkgs.helix                         # full grammar set (cached)
  # or trim to just what you need (helix-unwrapped still cache-hits):
  # pkgs.helix.override {
  #   includeGrammarIf = g: builtins.elem g.name [ "rust" "nix" "python" "toml" ];
  # }
}
```

`overlays.default` adds `helix` and `helix-unwrapped` to `pkgs`. The flake also declares
the cache as a substituter via `nixConfig`, so consumers pull prebuilt binaries
automatically (Nix will ask to trust the substituter the first time).

`includeGrammarIf` is a predicate `grammar -> bool` where `grammar` is an attrset with
`.name` (and `.source`), forwarded straight to upstream's `grammars.nix`.

## Bumping helix

`nix flake update helix-src`. CI also does this daily and commits the new lock **only if
the build succeeds**, so a broken master never reaches consumers.

## CI / cache setup (one-time)

- Repo secret `CACHIX_AUTH_TOKEN` (a write token for the `0x130c` cache).
- The public key is already pinned in `flake.nix` `nixConfig`.

CI pushes only the **runtime closure** of the outputs (`nix path-info -r ... | cachix
push`), so cargo vendor dirs and the rust toolchain are never cached.
