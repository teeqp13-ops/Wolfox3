<?php

declare(strict_types=1);

use WolFox\Store\App;
use WolFox\Store\Config;
use WolFox\Store\Http;
use WolFox\Store\Security\TelegramInitData;

require dirname(__DIR__, 2) . '/src/bootstrap.php';

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    Http::json(['error' => 'Method not allowed.'], 405);
}

try {
    $input = Http::input();
    $productId = filter_var($input['product_id'] ?? null, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);
    if ($productId === false) {
        throw new InvalidArgumentException('رقم المنتج غير صالح.');
    }

    $phone = preg_replace('/\D+/', '', (string) ($input['phone'] ?? '')) ?? '';
    if ($phone !== '' && (strlen($phone) < 8 || strlen($phone) > 15)) {
        throw new InvalidArgumentException('رقم WhatsApp غير صالح.');
    }

    $telegramUser = [];
    $initData = (string) ($input['init_data'] ?? '');
    if ($initData !== '') {
        $botToken = Config::get('TELEGRAM_BOT_TOKEN', '') ?? '';
        $telegramUser = TelegramInitData::validate(
            $initData,
            $botToken,
            Config::int('TELEGRAM_INIT_DATA_MAX_AGE', 86400)
        );
    }
    if ($phone === '' && empty($telegramUser['id'])) {
        throw new InvalidArgumentException('افتح المتجر من Telegram أو أدخل رقم WhatsApp للتسليم.');
    }

    $customer = [
        'telegram_user_id' => isset($telegramUser['id']) ? (string) $telegramUser['id'] : null,
        'telegram_username' => isset($telegramUser['username']) ? (string) $telegramUser['username'] : null,
        'customer_phone' => $phone !== '' ? $phone : null,
    ];

    $app = new App();
    $result = $app->orderService->create((int) $productId, $customer);
    Http::json($result, 201);
} catch (InvalidArgumentException $error) {
    Http::json(['error' => $error->getMessage()], 422);
} catch (Throwable $error) {
    error_log('order_create_failed: ' . $error->getMessage());
    Http::json(['error' => 'تعذر إنشاء الطلب حالياً.'], 500);
}
