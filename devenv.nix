# devenv.nix
#
# Refer to docs/architecture.md for an overview of the architecture
# and design decisions
#
# ─────────────────────────────────────────────────────────────────────────────
# USAGE
# ─────────────────────────────────────────────────────────────────────────────
#
#   devenv up          → start Caddy + PHP-FPM + MariaDB + Adminer
#   devenv shell       → enter the shell with all tools in PATH
#   lamp-status        → check whether services are reachable
#   lamp-db            → open a MariaDB CLI session against uni_db
#   lamp-logs          → tail the PHP-FPM error log
#   lamp-php-info      → dump PHP build info to terminal
#
#   Document root: ./www/
#   Web:           http://localhost:8080
#   Adminer:       http://localhost:8081

{
  pkgs,
  config,
  ...
}:

{
  # ── PHP ──────────────────────────────────────────────────────────────────────
  languages.php = {
    enable = true;
    version = "8.3";
    extensions = [
      "mysqli"
      "pdo"
      "pdo_mysql"
      "mbstring"
      "curl"
      "openssl"
      "tokenizer"
    ];
    # php.ini overrides applied to all FPM pools in this environment.
    # display_errors = On surfaces PHP errors in the browser — must be Off
    # in production. These values mirror XAMPP's development defaults.
    ini = ''
      display_errors = On
      error_reporting = E_ALL
      log_errors = On
      memory_limit = 256M
      upload_max_filesize = 64M
      post_max_size = 64M
    '';
    # ── PHP-FPM pool ────────────────────────────────────────────────────────
    # FPM manages a pool of PHP worker processes. Caddy sends FastCGI requests
    # to the Unix socket this pool exposes. The socket path is managed by
    # devenv and referenced in the Caddy virtualHost config below as:
    #   config.languages.php.fpm.pools.web.socket
    # pm = dynamic: FPM spawns workers on demand between min and max bounds,
    # which is appropriate for a low-traffic local dev environment.
    fpm.pools.web = {
      settings = {
        "pm" = "dynamic";
        "pm.max_children" = 10;
        "pm.start_servers" = 2;
        "pm.min_spare_servers" = 1;
        "pm.max_spare_servers" = 5;
      };
    };
  };

  # ── Caddy HTTP Server ─────────────────────────────────────────────────────────
  # Listens on port 8080 (non-privileged) to avoid requiring root.
  # Document root is ./www/ relative to the project directory.
  services.caddy = {
    enable = true;
    virtualHosts."http://localhost:8080" = {
      extraConfig = ''
        # Serve files from the project's www/ directory.
        root * ${config.devenv.root}/www

        # Forward all .php requests to the PHP-FPM pool via FastCGI.
        # The socket path is declared by the fpm.pools.web block above and
        # resolved at evaluation time by Nix — no hardcoded paths.
        php_fastcgi unix/${config.languages.php.fpm.pools.web.socket}

        # Serve static files (HTML, CSS, JS, images) directly.
        file_server
      '';
    };
  };

  # ── Adminer (phpMyAdmin equivalent) ──────────────────────────────────────────  #
  # Access at: http://localhost:8081
  # Login with configured credentials:
  #   server=127.0.0.1, user=cypher, password=cypher, database=uni_db
  services.adminer = {
    enable = true;
    listen = "127.0.0.1:8081";
  };

  # ── MariaDB ───────────────────────────────────────────────────────────────────
  # Runs as a local MariaDB instance on the standard port 3306.
  # initialDatabases and ensureUsers run only on first devenv up (when the
  # data directory does not yet exist) — they are idempotent bootstrappers,
  # not commands that re-run on every start.
  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    initialDatabases = [ { name = "uni_db"; } ];
    ensureUsers = [
      {
        name = "cypher";
        password = "cypher";
        ensurePermissions = {
          "uni_db.*" = "ALL PRIVILEGES";
        };
      }
    ];
  };

  # ── Perl (XAMPP faithfulness) ─────────────────────────────────────────────────
  # Perl is the second P in XAMPP. Historically used for CGI scripts before PHP
  # became dominant. Included for completeness. Uncomment to activate.
  #
  # languages.perl = {
  #   enable = true;
  #   package = pkgs.perl;
  # };
  #
  # With Perl enabled, a CGI script at ./www/cgi-bin/hello.pl would be accessible
  # at http://localhost:8080/cgi-bin/hello.pl, provided Caddy is configured to
  # proxy CGI execution. Caddy does not natively support CGI — a shim like
  # caddy-cgi (a Caddy plugin) or a separate CGI-capable process would be needed.
  # For simplicity, Perl CGI scripts are better tested via `perl script.pl`
  # directly in the shell when this course requires it.

  # ── Laravel (optional — future-proofing) ─────────────────────────────────────
  # Laravel is PHP's dominant full-stack web framework. It does not change the
  # infrastructure stack (Caddy + MariaDB + PHP remain identical) — it is an
  # application layer that runs on top of it.
  #
  # What Laravel adds:
  #   Eloquent ORM      — PHP models that map to DB tables; no raw SQL required
  #   Blade templates   — clean HTML templating engine for server-rendered views
  #   Artisan CLI       — scaffolding, migrations, and app management from terminal
  #   Migrations        — DB schema changes as version-controlled PHP files
  #   Routing, auth,
  #   queues, mail      — all built in and coherent
  #
  # To bootstrap a Laravel project inside this environment:
  #   1. Uncomment the block below and run `devenv shell` (or let direnv reload)
  #   2. From ./www/: composer create-project laravel/laravel .
  #   3. Configure ./www/.env: set DB_HOST=127.0.0.1, DB_DATABASE=uni_db,
  #      DB_USERNAME=cypher, DB_PASSWORD=cypher
  #   4. php artisan migrate
  #
  # Composer is the PHP package manager — the npm of the PHP ecosystem.
  # It must be in PATH for Laravel's installer to work.
  #
  # home.packages = [
  #   pkgs.php83Packages.composer
  # ];
  #
  # Note: composer is a home.packages entry, not a devenv languages/services
  # option, because it is a globally useful PHP tool rather than
  # a project-scoped service. Add it to your HM dev packages module instead
  # if you plan to use it across multiple projects.

  # ── Scripts ───────────────────────────────────────────────────────────────────
  # Scripts declared here become shell commands available inside the devenv
  # shell. They are the Nix-native equivalent of XAMPP's start/stop UI buttons.

  scripts.lamp-status.exec = ''
    echo "=== LAMP Status ==="
    echo ""
    echo "[ Caddy ]"
    ${pkgs.curl}/bin/curl -s -o /dev/null -w "  HTTP Status: %{http_code}\n" \
      http://127.0.0.1:8080 \
      && echo "  Reachable:   YES" \
      || echo "  Reachable:   NO  (run 'devenv up')"
    echo ""
    echo "[ MariaDB ]"
    ${pkgs.mariadb}/bin/mysqladmin \
      --user=cypher \
      --password=cypher \
      --host=127.0.0.1 \
      status 2>/dev/null \
      && echo "  Reachable:   YES" \
      || echo "  Reachable:   NO  (run 'devenv up')"
    echo ""
    echo "[ Adminer ]"
    ${pkgs.curl}/bin/curl -s -o /dev/null -w "  HTTP Status: %{http_code}\n" \
      http://127.0.0.1:8081 \
      && echo "  URL:         http://localhost:8081" \
      || echo "  Unreachable  (run 'devenv up')"
  '';

  scripts.lamp-db.exec = ''
    # Opens an interactive MariaDB session against uni_db.
    ${pkgs.mariadb}/bin/mysql \
      --user=cypher \
      --password=cypher \
      --host=127.0.0.1 \
      uni_db
  '';

  scripts.lamp-logs.exec = ''
    # Tails the PHP-FPM error log — first place to look when PHP throws errors.
    # The log lives under devenv's state directory, scoped to the web pool.
    tail -f ${config.devenv.root}/.devenv/state/php-fpm/web.log 2>/dev/null \
      || echo "No FPM log yet — run 'devenv up' first"
  '';

  scripts.lamp-php-info.exec = ''
    # Dumps the PHP build summary — loaded extensions, ini values, version.
    php -r "phpinfo();" | ${pkgs.gnugrep}/bin/grep -E \
      "PHP Version|Loaded Configuration|extension_dir|mysqli|pdo|mbstring|curl|openssl"
  '';

  # ── Shell entry banner ────────────────────────────────────────────────────────
  # Runs once on shell activation (via direnv cd or `devenv shell`).
  # Also ensures the document root exists before Caddy tries to serve from it.
  enterShell = ''
    mkdir -p ${config.devenv.root}/www
    echo ""
    echo "  ┌──────────────────────────────────────────┐"
    echo "  │   LAMP Dev Environment — uni_course      │"
    echo "  │                                          │"
    echo "  │   devenv up         → start services     │"
    echo "  │   lamp-status       → check status       │"
    echo "  │   lamp-db           → MariaDB CLI        │"
    echo "  │   lamp-logs         → PHP-FPM error log  │"
    echo "  │   lamp-php-info     → PHP build info     │"
    echo "  │                                          │"
    echo "  │   Web:        http://localhost:8080      │"
    echo "  │   Adminer:    http://localhost:8081      │"
    echo "  │                                          │"
    echo "  └──────────────────────────────────────────┘"
    echo ""
  '';
}
