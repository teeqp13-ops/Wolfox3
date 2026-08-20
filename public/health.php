<?php

declare(strict_types=1);

use WolFox\Store\App;
use WolFox\Store\Http;

require dirname(__DIR__) . '/src/bootstrap.php';

try {
    $app = new App();
    $app->database->pdo()->query('SELECT 1')->fetchColumn();
    Http::json(['ok' => true, 'service' => 'wolfox-store', 'time' => date(DATE_ATOM)]);
} catch (Throwable $error) {
    Http::json(['ok' => false, 'service' => 'wolfox-store'], 503);
}
