<?php

declare(strict_types=1);

use WolFox\Store\App;
use WolFox\Store\Config;

require dirname(__DIR__, 2) . '/src/bootstrap.php';

if ((Config::get('APP_ENV', 'production') ?? 'production') === 'production' || (Config::get('PAYMENT_DRIVER', 'mock') ?? 'mock') !== 'mock') {
    http_response_code(404);
    exit('Not found.');
}

$orderNumber = (string) ($_GET['order'] ?? '');
$payload = json_encode([
    'event_id' => 'mock-' . bin2hex(random_bytes(6)),
    'order_number' => $orderNumber,
    'transaction_id' => 'mock-tx-' . bin2hex(random_bytes(5)),
    'status' => 'paid',
], JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR);

$app = new App();
$result = $app->orderService->handlePayment($payload, []);
?>
<!doctype html><html lang="ar" dir="rtl"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>دفع تجريبي</title><style>body{font-family:system-ui;background:#07111f;color:#fff;display:grid;place-items:center;min-height:100vh;margin:0}.box{max-width:520px;padding:32px;border:1px solid #27374c;border-radius:24px;background:#0b1422;text-align:center}a{color:#52adff}</style>
<div class="box"><h1>تم الدفع التجريبي ✅</h1><p>الطلب <?= htmlspecialchars((string) $result['order']['order_number'], ENT_QUOTES, 'UTF-8') ?> أصبح مدفوعاً.</p><a href="/">العودة للمتجر</a></div></html>
