<?php

declare(strict_types=1);

use WolFox\Store\App;
use WolFox\Store\Http;

require dirname(__DIR__, 2) . '/src/bootstrap.php';

if (($_SERVER['REQUEST_METHOD'] ?? 'GET') !== 'GET') {
    Http::json(['error' => 'Method not allowed.'], 405);
}

$app = new App();
Http::json(['products' => $app->products->active()]);
