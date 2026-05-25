# [2026-05-12 → 2026-05-22] NixAMP — LAMP Dev Environment via devenv on NixOS

<!-- The journal is informal. This is the human layer on top of git history.
     Write like you're explaining the session to yourself six months from now.
     What happened, what you figured out, what you're still unsure about.
     No polish required. Honest > polished. -->

**Date:** 2026-05-12 → 2026-05-22
**Duration:** ~10 hours (across multiple sessions)
**Repos touched:** nixamp, CypherOS
**Phase:** Setup & Environment Bootstrapping

---

## What I Worked On

Setting up a XAMPP-equivalent local development environment on NixOS using devenv,
as a requirement for a university internet programming course (backend and databases,
PHP tooling). The goal was to replicate what XAMPP provides — Apache/web server,
MariaDB, PHP, and a browser-based DB UI — but in a reproducible, Nix-native,
declarative way rather than installing a monolithic bundle.

This also became the entry point for understanding devenv, direnv, and nix-direnv —
tools that had been on the radar but never hands-on until now.

---

## What Got Done

- Understood what XAMPP actually is: not an app but a pre-bundled stack acronym
  (X cross-platform, A Apache, M MariaDB, P PHP, P Perl), and why the Nix-native
  equivalent is more powerful despite requiring more deliberate setup
- Understood the three-tier CypherOS dev tooling model:
  Tier 1 (NixOS system services) → Tier 2 (HM global tools) → Tier 3 (per-project devShells)
- Added `devenv` to CypherOS flake inputs and HM packages module
- Added `programs.direnv` with `nix-direnv.enable = true` to HM config as a
  dedicated `modules/home/devenv.nix` with `cypher-os.dev.devenv.enable` toggle
- Fixed a silent breakage in the standalone `homeConfigurations` entry in `flake.nix`
  — `inputs.catppuccin.homeModules.catppuccin` was missing from that evaluation
  context, causing a hard evaluation failure that was invisible during normal
  `nixos-rebuild switch` (which uses `nixosConfigurations`, not `homeConfigurations`)
- Wrote `devenv.nix` for the nixamp project declaring:
  - PHP 8.3 with mysqli, pdo, pdo_mysql, mbstring, curl, openssl, tokenizer extensions
  - PHP-FPM pool (`web`) as the PHP process manager
  - Caddy HTTP server on port 8080 (devenv ships Caddy, not Apache)
  - MariaDB via `services.mysql` with `uni_db` database and `cypher` user bootstrapped
  - Adminer on port 8081 as the browser-based DB UI (phpMyAdmin ruled out — no stable
    nixpkgs derivation exists)
  - `lamp-status`, `lamp-db`, `lamp-logs`, `lamp-php-info` shell scripts as the
    XAMPP control panel equivalent
- Wired direnv via `.envrc` with `eval "$(devenv direnvrc)"` + `use devenv`
- Verified full stack with three PHP test files:
  - `www/index.php` — confirmed PHP executing through Caddy + PHP-FPM
  - `www/db.php` — confirmed mysqli and PDO connectivity to MariaDB
  - `www/info.php` — confirmed PHP build info and loaded extensions

---

## Key Decisions Made

**Caddy over Apache:** devenv does not ship an Apache service — Caddy is the only
available web server. This is actually architecturally superior: Caddy + PHP-FPM
is the production-preferred split-daemon model, whereas XAMPP's Apache uses mod_php
(PHP running inside Apache). Documented in architecture.md.

**Adminer over phpMyAdmin:** phpMyAdmin has no stable, declaratively usable nixpkgs
derivation. Adminer is a single-file PHP app with first-class devenv service support.
Functionally equivalent for coursework purposes.

**`languages.php.extensions` over `buildEnv`:** devenv's native `extensions` string
list is the correct approach. Using `buildEnv` directly requires exact nixpkgs PHP
extension attribute names — `json` doesn't exist as a standalone extension in PHP 8.x
(it's compiled into core), which caused a hard evaluation failure when listed.

**One `.envrc` pattern:** `eval "$(devenv direnvrc)"` must precede `use devenv`.
`use_devenv` is not provided by nix-direnv (which only provides `use_flake` and
`use_nix`) — it's provided by devenv's own direnvrc. Conflating nix-direnv and
devenv's direnv integration is a common mistake.

**Standalone HM catppuccin fix:** Every flake input that contributes HM modules must
be explicitly imported in every HM evaluation context. The `nixosConfigurations` path
had `inputs.catppuccin.homeModules.catppuccin` in its imports list. The standalone
`homeConfigurations` path did not. This caused a silent breakage that only surfaced
when directly evaluating the standalone configuration.

---

## Where I Got Stuck

**`use_devenv: command not found`** — Lost time assuming nix-direnv provides
`use_devenv`. It doesn't. nix-direnv provides `use_flake` and `use_nix`. devenv
provides `use_devenv` via its own `direnvrc` command, which must be explicitly sourced
in `.envrc` via `eval "$(devenv direnvrc)"`. The fix is a one-liner but the mental
model gap was costly.

**`services.apache-httpd` does not exist** — Assumed devenv would mirror NixOS module
names. It doesn't ship Apache at all. The error message's suggestion of `services.adminer`
was the clue that led to discovering devenv's actual web server is Caddy.

**`languages.php.fpm.enable` does not exist** — devenv's PHP module doesn't have a
standalone `fpm.enable` toggle. FPM is activated implicitly by declaring `fpm.pools`.

**`undefined variable 'json'`** — `json` is not a PHP extension attribute in nixpkgs.
In PHP 8.x, JSON support is compiled directly into the interpreter core. It cannot be
loaded as an extension and has no corresponding nixpkgs derivation to reference in
`buildEnv`. Same category of mistake: assuming a capability is an extension when it's
actually baked in.

**`The option 'catppuccin' does not exist` in standalone HM** — surfaced when running
`nix eval` on the standalone `homeConfigurations` entry to diagnose the direnv issue.
The standalone config had never been evaluated directly before, so the breakage was
invisible. Required adding `inputs.catppuccin.homeModules.catppuccin` to the
`homeConfigurations` modules list in `flake.nix`.

---

## What I Learned

**XAMPP is a stack, not a framework.** A stack is a named collection of pre-selected
tools known to work together. A framework imposes structure on your code. XAMPP just
bundles and pre-wires tools — the acronym is marketing shorthand.

**The three-tier CypherOS dev tooling model** is now concrete:
- Tier 1: NixOS system modules → daemons, systemd services
- Tier 2: Home Manager → global CLI tools always in PATH
- Tier 3: devShells / devenv → per-project, ephemeral, context-scoped

devShells don't replace Tier 2 — they extend below it. The instinct to group tools
into "DevOps devShell", "mobile devShell" etc. is valid and maps to a template library
inside CypherOS that individual project flakes can import.

**direnv ≠ nix-direnv ≠ devenv's direnv integration.** Three distinct things:
- direnv: directory-scoped env activation via `.envrc`
- nix-direnv: teaches direnv to understand `use flake` with caching
- devenv direnvrc: teaches direnv to understand `use devenv`
All three must be present and correctly ordered for the full chain to work.

**Caddy + PHP-FPM is more production-representative than Apache + mod_php.** The
XAMPP setup most courses teach (mod_php inside Apache) is actually the legacy
architecture. The split-daemon model (web server + separate PHP process manager
communicating via FastCGI/Unix socket) is what production environments use.

**Every HM module flake input must be imported in every evaluation context.** Not just
the NixOS-integrated path. This is a pattern to internalize for all future HM module
flakes added to CypherOS.

**`json` is not a PHP extension.** Since PHP 8.0, JSON support is a mandatory core
component compiled into the interpreter itself. It cannot be disabled or loaded
separately.

---

## Open Questions

- devenv 2.1.2 is available (running 2.0.6) — update path via `nix flake update devenv`
  in CypherOS root, then `nixos-rebuild switch`. Not urgent but worth scheduling.
- The `spin-up / spin-down` workflow for heavier environments (pentest lab, full DevOps
  stack) maps to NixOS Containers (`nixos-container`), not devShells. Worth exploring
  once the Cloud/DevOps module work begins.
- Laravel is future-proofed in the commented block in `devenv.nix` — composer needs to
  be added to the HM dev packages module when the time comes.

---

## Next Session

Begin actual PHP coursework using the running stack. The environment is stable —
`devenv up` from the project directory starts all four services (Caddy, PHP-FPM,
MariaDB, Adminer). Course PHP files go into `./www/`.

---

<!--
Commit range (fill in after session):
nixamp:    [initial commit hash] → [short hash]
CypherOS: [short hash] → [short hash]
-->
