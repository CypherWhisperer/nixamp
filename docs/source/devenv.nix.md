<!--
Deliberate annotation — forcing the self to articulate why every construct exists before moving past it. The payoff isn't the doc file; it's the cognitive forcing function. When you can't write a sentence explaining a block, you've found a gap.
-->

# devenv.nix — nixamp LAMP Stack Definition

> Declares the full local development environment for nixamp: PHP 8.3, Caddy, PHP-FPM, MariaDB, and Adminer. The ancestor environment from which devlog and future PHP projects are extended.

**File:** `devenv.nix`
**Environment:** devenv (_via `devenv.yaml` + direnv `use devenv`_)
**Status:** Stable
**Last reviewed:** 2026-06-07

---

## Responsibility

**Does:**

- Declares all services required to run a LAMP stack locally
- Defines all `lamp-*` helper scripts as devenv-managed shell commands
- Prints the shell entry banner and ensures `www/` exists on activation
- Serves as the reference environment that downstream projects (_devlog, future PHP coursework_) extend and specialise

**Does not:**

- Manage application code — _document root `./www/` is untracked_
- Handle production configuration — _dev-only_
- Include Composer by default — _downstream projects add it if needed_

---

## Block Analysis

---

### Block 1 — `languages.php`

**What is this?** devenv's PHP language module. Enables PHP 8.3 with
a set of extensions and custom `php.ini` overrides.

**What does it do?** Installs the PHP 8.3 interpreter into the devenv
shell's PATH and activates the listed extensions. The `ini` block
injects additional directives into the effective `php.ini` at runtime.

**Why is it here?** nixamp is a PHP development environment. The
extension set covers the full range of coursework needs: `mysqli` and
`pdo_mysql` for database access, `mbstring` for string handling, `curl`
and `openssl` for HTTP and crypto, `tokenizer` for any Composer use.
`fileinfo` is intentionally excluded here — it was added in devlog for
Milestone 5 file upload handling, which is out of scope for the base
environment.

```nix
languages.php = {
  enable = true;
  version = "8.3";
  extensions = [
    "mysqli" "pdo" "pdo_mysql" "mbstring"
    "curl" "openssl" "tokenizer"
  ];
  ini = ''
    display_errors = On
    error_reporting = E_ALL
    log_errors = On
    memory_limit = 256M
    upload_max_filesize = 64M
    post_max_size = 64M
  '';
  ...
};
```

> ⚠️ `display_errors = On` surfaces PHP errors in the browser.
> Intentional in development — must be `Off` in production.

---

### Block 2 — `languages.php.fpm.pools.web`

**What is this?** Configuration for a PHP-FPM process pool named `web`.

**What does it do?** Spawns a pool of PHP worker processes managed by
FPM. Exposes a Unix socket that Caddy uses to forward FastCGI requests.
The socket path is resolved at Nix eval time via
`config.languages.php.fpm.pools.web.socket` — never hardcoded.

**Why is it here?** Caddy does not execute PHP directly. It speaks
FastCGI to FPM, which executes PHP scripts in managed worker processes.
`pm = dynamic` is appropriate for local dev.

```nix
fpm.pools.web = {
  settings = {
    "pm"                   = "dynamic";
    "pm.max_children"      = 10;
    "pm.start_servers"     = 2;
    "pm.min_spare_servers" = 1;
    "pm.max_spare_servers" = 5;
  };
};
```

---

### Block 3 — `services.caddy`

**What is this?** devenv's Caddy service declaration.

**What does it do?** Starts a Caddy HTTP server on port 8080. Serves
static files from `./www/`. Forwards PHP requests to the FPM pool via
FastCGI. No front-controller rewrite — files are served directly,
matching traditional XAMPP behaviour for coursework.

**Why is it here?** nixamp is a XAMPP analogue for NixOS. The `./www/`
document root mirrors XAMPP's `htdocs/` convention. Unlike devlog,
there is no front controller — PHP files are accessed directly by path,
which is the typical pattern for introductory PHP coursework.

```nix
services.caddy = {
  enable = true;
  virtualHosts."http://localhost:8080" = {
    extraConfig = ''
      root * ${config.devenv.root}/www
      php_fastcgi unix/${config.languages.php.fpm.pools.web.socket}
      file_server
    '';
  };
};
```

> Note: `.htaccess` is Apache-only and has no effect under Caddy.

---

### Block 4 — `services.adminer`

**What is this?** devenv's Adminer service declaration.

**What does it do?** Starts an Adminer instance on port 8081.

**Why is it here?** Provides a GUI database interface equivalent to
phpMyAdmin in XAMPP.

```nix
services.adminer = {
  enable = true;
  listen = "127.0.0.1:8081";
};
```

> Login: server `127.0.0.1`, user `cypher`, password `cypher`,
> database `uni_db`.

---

### Block 5 — `services.mysql`

**What is this?** devenv's MariaDB service declaration.

**What does it do?** Starts a MariaDB instance. On first `devenv up`,
creates the `uni_db` database and the `cypher` user with full
privileges. One-time bootstrap — does not re-run or reset data on
subsequent starts.

**Why is it here?** MariaDB is the M in LAMP. `pkgs.mariadb` is
specified explicitly to pin the engine.

```nix
services.mysql = {
  enable   = true;
  package  = pkgs.mariadb;
  initialDatabases = [ { name = "uni_db"; } ];
  ensureUsers = [
    {
      name     = "cypher";
      password = "cypher";
      ensurePermissions = { "uni_db.*" = "ALL PRIVILEGES"; };
    }
  ];
};
```

> ⚠️ **Socket path note**: ([ADR_001](../project/decisions/ADR_001_2026_06_07_devenv_runtime_socket_convention.md)): The MariaDB socket is at
> `$DEVENV_RUNTIME/mysql.sock`. Never hardcode this path. See ADR_001.

---

### Block 6 — `scripts`

**What is this?** Named shell commands exposed inside the devenv shell.

| Script           | Purpose                                        |
| ---------------- | ---------------------------------------------- |
| `lamp-status`    | Health check for all three services            |
| `lamp-db`        | Interactive MariaDB CLI as the cypher user     |
| `lamp-logs`      | Tail PHP-FPM error log                         |
| `lamp-php-info`  | Dump PHP build info and loaded extensions      |

> `lamp-status` uses `--user=root` for the mysqladmin ping.

---

### Block 7 — `enterShell`

**What is this?** Shell hook that runs once on devenv activation.

**What does it do?** Creates `./www/` if it does not exist, then
prints the service reference banner.

**Why is it here?** `./www/` is the document root Caddy serves from.
It is not tracked by git (coursework files are ephemeral). Creating it
here ensures Caddy always has a valid root to start from.

---

### Block 8 — Commented blocks (Perl, Laravel, Composer)

**What is this?** Three commented-out configuration blocks with
explanatory prose.

**What does it do?** Nothing at runtime — these are documentation
stubs for features that are available but not activated by default.

**Why is it here?** nixamp is an educational environment. The comments
explain what Perl CGI and Laravel are, why they aren't active, and how
to enable them when needed. This is deliberate — the file doubles as
orientation material for someone new to the LAMP stack.

---

## Dependencies

**devenv services used:**

- `languages.php` — PHP interpreter and FPM
- `services.caddy` — HTTP server
- `services.adminer` — database UI
- `services.mysql` — MariaDB

**nixpkgs packages required:**

- `pkgs.mariadb` — MariaDB server and client binaries
- `pkgs.curl` — used in lamp-status health checks
- `pkgs.gnugrep` — used in lamp-php-info

**Runtime environment variables:**

- `$DEVENV_RUNTIME` — set by devenv; base path for all service sockets
- `config.devenv.root` — resolved at Nix eval time; absolute project root path
- `config.languages.php.fpm.pools.web.socket` — resolved at Nix eval time; FPM socket

---

## Known Limitations

- No `try_files` rewrite — clean URLs are not supported. Each PHP file
  must be accessed by its explicit path. Intentional for coursework use.
- No Composer by default — downstream projects add it as needed.
- `lamp-db` script has a syntax error in the source: the `mysql` binary
  invocation is missing. The socket flag appears without the binary on
  the preceding line. Fix before use.

---

## Related

| Type      | Reference                                                              |
| --------- | ---------------------------------------------------------------------- |
| ADR       | [ADR_001](../project/decisions/ADR_001_2026_06_07_devenv_runtime_socket_convention.md) |
| Companion | [`devenv.yaml.md`](./devenv.yaml.md)                                   |
| Downstream | devlog `docs/source/devenv.nix.md`                                    |

---

<!-- METADATA
File:    devenv.nix
Created: 2026-xx-xx
Updated: 2026-06-07
-->
