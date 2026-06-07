# ADR_001_2026_06_07: Use $DEVENV_RUNTIME for MariaDB Socket Path

**Date:** 2026-06-07
**Status:** Accepted
**Deciders:** CypherWhisperer

---

## Context

devenv computes a runtime directory dynamically at startup, using
`XDG_RUNTIME_DIR` (_on NixOS/systemd systems_) or `TMPDIR` (elsewhere) as
the base. The MariaDB socket is placed at `$DEVENV_RUNTIME/mysql.sock`.

The original nixamp devenv.nix scripts hardcoded the socket path as
`.devenv/state/mysql/mysql.sock`. This path reflected an older devenv
behaviour and does not match where devenv places the socket after a
nixpkgs update.

The mismatch was discovered indirectly: the same bug surfaced in devlog
(a project extended from nixamp) and caused all MariaDB scripts —
lamp-status, lamp-db — to report the database as unreachable even though
MariaDB was running correctly. Diagnosis took approximately two days and
incorrectly attributed the failure to ensureUsers before the socket path
was identified as the actual cause via `find /run/user/1000 -name "*.sock"`.

nixamp inherited the bug from its own scripts and carries the same fix.
This is nixamp's founding ADR, establishing the socket path convention
for all future scripts in this project.

---

## Decision

All nixamp devenv.nix scripts that reference the MariaDB socket must use
`$DEVENV_RUNTIME/mysql.sock`. Hardcoded socket paths are prohibited.

---

## Reasoning

`$DEVENV_RUNTIME` is the only reliable reference because devenv's runtime
directory is computed dynamically and is not guaranteed to be stable across nixpkgs updates, machines, or environments. Hardcoding the path produces silent failures that are difficult to diagnose — the service appears broken when it is in fact reachable.

The environment variable is always set by devenv when scripts execute.
There is no availability concern for devenv-internal scripts.

This convention was validated in devlog before being adopted here.

---

## Alternatives Considered

### Hardcoded .devenv/state/mysql/mysql.sock

The original approach. Worked at some point but broke after a nixpkgs
update changed where devenv places the socket. Rejected because it is
fragile across updates and environments, and fails silently.

### config.devenv.root interpolation at Nix eval time

Using `${config.devenv.root}/.devenv/state/mysql/mysql.sock` in the Nix
expression. Rejected for the same reason — the path itself is wrong
regardless of how it is constructed.

---

## Consequences

**Positive:**

- Scripts are robust across nixpkgs updates and machines
- Socket path is always correct regardless of devenv version or OS
- Convention is consistent with devlog, reducing cognitive overhead
  when working across both projects

**Negative / Trade-offs:**

- `$DEVENV_RUNTIME` is only set inside a devenv shell. Scripts run
  outside that context will fail. Acceptable — all lamp-* scripts are
  devenv-internal by design.

**Neutral / Operational:**

- Apply immediately to lamp-status and lamp-db in devenv.nix
- All future devenv projects in this workspace adopt this convention
  from the start; do not hardcode socket paths

---

<!-- METADATA
Created: 2026-06-07
Related incident: devlog INC_2026_06_05_001
Related ADR:      devlog ADR_004_2026_06_07_devenv_runtime_socket_convention.md
-->
