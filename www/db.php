<?php
// db.php:
// This file serves to confirms PHP → MariaDB connectivity via mysqli and PDO.

$host = '127.0.0.1';
$db   = 'uni_db';
$user = 'cypher';
$pass = 'cypher';

$results = [];

// ── mysqli test ──────────────────────────────────────────────────────────────
$mysqli = new mysqli($host, $user, $pass, $db);
if ($mysqli->connect_error) {
    $results['mysqli'] = 'FAIL — ' . $mysqli->connect_error;
} else {
    $row = $mysqli->query("SELECT VERSION() AS version")->fetch_assoc();
    $results['mysqli'] = 'OK — MariaDB ' . $row['version'];
    $mysqli->close();
}

// ── PDO test ─────────────────────────────────────────────────────────────────
try {
    $pdo = new PDO("mysql:host=$host;dbname=$db", $user, $pass);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $version = $pdo->query("SELECT VERSION()")->fetchColumn();
    $results['PDO'] = 'OK — MariaDB ' . $version;
} catch (PDOException $e) {
    $results['PDO'] = 'FAIL — ' . $e->getMessage();
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>DB Connectivity Test</title>
    <style>
        body { font-family: monospace; padding: 2rem; background: #0f0f0f; color: #e0e0e0; }
        h1 { color: #7aa2f7; }
        .ok   { color: #9ece6a; }
        .fail { color: #f7768e; }
        p { margin: 0.4rem 0; }
    </style>
</head>
<body>
    <h1>DB Connectivity Test</h1>
    <?php foreach ($results as $driver => $result): ?>
    <p class="<?= str_starts_with($result, 'OK') ? 'ok' : 'fail' ?>">
        [<?= htmlspecialchars($driver) ?>] <?= htmlspecialchars($result) ?>
    </p>
    <?php endforeach; ?>
</body>
</html>
