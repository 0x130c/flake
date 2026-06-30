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
  # pkgs.helix                         # curated grammar set (cached, see below)
  # or trim further (helix-unwrapped still cache-hits):
  # pkgs.helix.override {
  #   includeGrammarIf = g: builtins.elem g.name [ "rust" "nix" "python" "toml" ];
  # }
  # or take every grammar helix supports:
  # pkgs.helix.override { includeGrammarIf = _: true; }
}
```

`overlays.default` adds `helix` and `helix-unwrapped` to `pkgs`. The flake also declares
the cache as a substituter via `nixConfig`, so consumers pull prebuilt binaries
automatically (Nix will ask to trust the substituter the first time).

`includeGrammarIf` is a predicate `grammar -> bool` where `grammar` is an attrset with
`.name` (and `.source`), forwarded straight to upstream's `grammars.nix`.

## Grammar set (`grammars-enabled.txt`)

The default `helix` package builds only the grammars listed in
[`grammars-enabled.txt`](./grammars-enabled.txt) — one `[[grammar]].name` per line, with
`# …` annotations ignored — instead of all ~290 helix ships. That keeps the cache (and
your closure) to the languages actually in use. Edit the file to change the set; CI then
builds and caches exactly that. Helix's own `use-grammars.except` (currently `wren`,
`gemini`) is applied first, so those never build regardless.

## CI workflows

Three separate workflows, each with one job:

| Workflow | Triggers | Does | Pushes cache? |
|---|---|---|---|
| `build.yml` | push to `main`, PR, manual | build `helix-unwrapped` + `helix` (validate) | **no** |
| `push-cache.yml` | **manual only** (`workflow_dispatch`) | build + push runtime closures to `0x130c` | **yes** |
| `update.yml` | daily cron, manual | bump `helix-src`, build, commit lock on success | **no** |

Cache is populated **only by manually running `push-cache`** — nothing pushes
automatically. Typical flow: merge a change (or let `update` bump the lock), then run
`push-cache` from the Actions tab to refresh the cache.

`push-cache` pushes only the **runtime closure** of the outputs (`nix path-info -r … |
cachix push`), so cargo vendor dirs and the rust toolchain are never cached.

## Bumping helix

`nix flake update helix-src` locally, or run `update` (daily cron / manual) which bumps
and commits the new lock **only if the build succeeds**. Then run `push-cache` to cache
the new revision.

## One-time setup

- Repo secret `CACHIX_AUTH_TOKEN` (a write token for the `0x130c` cache).
- The cache's public key is already pinned in `flake.nix` `nixConfig`.
