<?php
// index.php:
// This file serves to confirms PHP is being served through Caddy + PHP-FPM
// If you see this rendered (not raw source), the stack is wired correctly.

$env = [
    'PHP Version'   => phpversion(),
    'Server'        => $_SERVER['SERVER_SOFTWARE'] ?? 'unknown',
    'Document Root' => $_SERVER['DOCUMENT_ROOT'] ?? 'unknown',
    'SAPI'          => php_sapi_name(),
];
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>LAMP Stack — Health Check</title>
    <style>
        body { font-family: monospace; padding: 2rem; background: #0f0f0f; color: #e0e0e0; }
        h1   { color: #7aa2f7; }
        table { border-collapse: collapse; margin-top: 1rem; }
        td, th { padding: 0.5rem 1.5rem 0.5rem 0; text-align: left; }
        th { color: #9ece6a; }
        .ok { color: #9ece6a; }
    </style>
</head>
<body>
    <h1>LAMP Stack — Health Check</h1>
    <p class="ok">✓ PHP is executing via Caddy + PHP-FPM</p>
    <table>
        <tr><th>Key</th><th>Value</th></tr>
        <?php foreach ($env as $key => $val): ?>
        <tr><td><?= htmlspecialchars($key) ?></td><td><?= htmlspecialchars($val) ?></td></tr>
        <?php endforeach; ?>
    </table>
</body>
</html>
