<?php

declare(strict_types=1);

use WolFox\Store\App;
use WolFox\Store\Security\TelegramInitData;

putenv('APP_ENV=testing');
putenv('PAYMENT_DRIVER=mock');
putenv('NERACHAT_ENABLED=0');
putenv('TELEGRAM_BOT_TOKEN=');

require dirname(__DIR__) . '/src/bootstrap.php';

$assertions = 0;
$assert = static function (bool $condition, string $message) use (&$assertions): void {
    $assertions++;
    if (!$condition) {
        throw new RuntimeException('Assertion failed: ' . $message);
    }
};

$databasePath = sys_get_temp_dir() . '/wolfox-store-test-' . bin2hex(random_bytes(6)) . '.sqlite';
$app = new App($databasePath);
$app->products->upsert([
    'slug' => 'test-product',
    'name_ar' => 'منتج تجريبي',
    'description_ar' => 'اختبار',
    'price_halalas' => 2500,
    'currency' => 'SAR',
    'image_url' => '',
    'active' => 1,
    'sort_order' => 1,
]);
$product = $app->products->active()[0];
$insertCode = $app->database->pdo()->prepare('INSERT INTO license_codes (product_id, code) VALUES (:product_id, :code)');
$insertCode->execute(['product_id' => $product['id'], 'code' => 'TEST-CODE-001']);

$created = $app->orderService->create((int) $product['id'], ['customer_phone' => '966500000000']);
$assert($created['order']['status'] === 'pending', 'new order starts pending');
$assert($created['order']['amount_halalas'] === 2500, 'price comes from database');

$callbackPayload = json_encode([
    'event_id' => 'event-001',
    'order_number' => $created['order']['order_number'],
    'transaction_id' => 'transaction-001',
    'status' => 'paid',
], JSON_THROW_ON_ERROR);
$paid = $app->orderService->handlePayment($callbackPayload, []);
$assert($paid['order']['status'] === 'paid', 'paid callback updates order');
$assert($paid['order']['license_code'] === 'TEST-CODE-001', 'paid order reserves available code');

$replayed = $app->orderService->handlePayment($callbackPayload, []);
$assert($replayed['order']['license_code'] === 'TEST-CODE-001', 'replayed webhook is idempotent');
$eventCount = (int) $app->database->pdo()->query('SELECT COUNT(*) FROM payment_events')->fetchColumn();
$assert($eventCount === 1, 'replayed webhook does not duplicate event');

$botToken = '123456:test-token';
$authDate = 1_700_000_000;
$values = [
    'auth_date' => (string) $authDate,
    'query_id' => 'AAExample',
    'user' => json_encode(['id' => 42, 'username' => 'wolfox_test'], JSON_UNESCAPED_SLASHES),
];
ksort($values, SORT_STRING);
$check = [];
foreach ($values as $key => $value) {
    $check[] = $key . '=' . $value;
}
$secret = hash_hmac('sha256', $botToken, 'WebAppData', true);
$values['hash'] = hash_hmac('sha256', implode("\n", $check), $secret);
$initData = http_build_query($values);
$telegramUser = TelegramInitData::validate($initData, $botToken, 3600, $authDate + 60);
$assert($telegramUser['id'] === 42, 'Telegram init data signature validates');

$index = file_get_contents(dirname(__DIR__) . '/public/index.php') ?: '';
$css = file_get_contents(dirname(__DIR__) . '/public/assets/app.css') ?: '';
$assert(str_contains($index, 'dir="rtl"'), 'storefront is RTL');
$assert(str_contains($css, 'html[data-theme="light"]'), 'light theme is implemented');

@unlink($databasePath);
@unlink($databasePath . '-shm');
@unlink($databasePath . '-wal');
fwrite(STDOUT, "OK — {$assertions} assertions passed.\n");
