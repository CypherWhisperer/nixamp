# devenv.yaml — nixamp Input Pins

> Declares the Nix input sources devenv uses to resolve packages and the devenv module system for this project.

**File:** `devenv.yaml`
**Status:** Stable
**Last reviewed:** 2026-06-07

---

## Responsibility

**Does:**

- Pins the nixpkgs channel devenv pulls packages from
- Documents the `allowUnfree`, `allowUnsupportedSystem`, and `imports` options available to this project

**Does not:**

- Configure services or packages — that is `devenv.nix`
- Control devenv's own version — that is pinned in `devenv.lock`

---

## Block Analysis

---

### Block 1 — `inputs.nixpkgs`

**What is this?** The nixpkgs flake input pointing at
`cachix/devenv-nixpkgs/rolling`.

**What does it do?** Pins the package set devenv resolves `pkgs.*`
against. `devenv-nixpkgs/rolling` is a curated rolling nixpkgs branch
maintained by the devenv team — it trails `nixos-unstable` slightly
but is tested against the devenv module set, reducing breakage risk
from nixpkgs updates.

**Why is it here?** nixamp uses devenv's own curated nixpkgs input
rather than raw `nixos-unstable` (as devlog does), which makes it
slightly more conservative about package updates. The tradeoff: it may
lag behind the host system's nixpkgs pin slightly.

```yaml
inputs:
  nixpkgs:
    url: github:cachix/devenv-nixpkgs/rolling
```

---

### Block 2 — Commented options

**What is this?** The schema-annotated comment block present in
devenv's default generated `devenv.yaml`.

**What does it do?** Nothing — these are documentation stubs for
`allowUnfree`, `allowUnsupportedSystem`, `permittedInsecurePackages`,
and `imports`. None are active.

**Why is it here?** Kept as a reference for available top-level options.
If a package requiring `allowUnfree` is needed in future, the option
is one uncomment away.

```yaml
# allowUnfree: true
# allowUnsupportedSystem: false
# permittedInsecurePackages:
#  - "openssl-1.1.1w"
# imports:
#  - ./backend
```

---

## nixpkgs pin comparison

| Project  | nixpkgs input                           | Notes                              |
| -------- | --------------------------------------- | ---------------------------------- |
| nixamp   | `cachix/devenv-nixpkgs/rolling`         | devenv-curated, lags unstable slightly |
| devlog   | `NixOS/nixpkgs/nixos-unstable`          | Raw unstable, closer to CypherOS host |

The difference is minor in practice but worth knowing if a package
version discrepancy appears between the two environments.

---

## Related

| Type      | Reference                                           |
| --------- | --------------------------------------------------- |
| Companion | [`devenv.nix.md`](./devenv.nix.md)                  |
| Lock file | `devenv.lock` (do not edit manually)                |

---

<!-- METADATA
File:    devenv.yaml
Created: 2026-xx-xx
Updated: 2026-06-07
-->
