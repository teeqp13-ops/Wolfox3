<?php

declare(strict_types=1);

use WolFox\Store\App;
use WolFox\Store\Http;

require dirname(__DIR__, 2) . '/src/bootstrap.php';

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    Http::json(['error' => 'Method not allowed.'], 405);
}

try {
    $rawBody = file_get_contents('php://input') ?: '';
    $app = new App();
    $result = $app->orderService->handlePayment($rawBody, $_SERVER);
    Http::json(['ok' => true, 'order_status' => $result['order']['status'], 'delivery' => $result['delivery']]);
} catch (InvalidArgumentException $error) {
    Http::json(['error' => $error->getMessage()], 400);
} catch (Throwable $error) {
    error_log('payment_callback_failed: ' . $error->getMessage());
    Http::json(['error' => 'Payment callback failed.'], 500);
}
