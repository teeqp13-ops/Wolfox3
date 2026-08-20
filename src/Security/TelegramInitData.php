<?php

declare(strict_types=1);

namespace WolFox\Store\Security;

use InvalidArgumentException;

final class TelegramInitData
{
    public static function validate(string $initData, string $botToken, int $maxAge = 86400, ?int $now = null): array
    {
        if ($initData === '' || $botToken === '') {
            throw new InvalidArgumentException('Telegram init data or bot token is missing.');
        }

        parse_str($initData, $values);
        $receivedHash = (string) ($values['hash'] ?? '');
        unset($values['hash']);
        if ($receivedHash === '') {
            throw new InvalidArgumentException('Telegram init data hash is missing.');
        }

        ksort($values, SORT_STRING);
        $check = [];
        foreach ($values as $key => $value) {
            $check[] = $key . '=' . $value;
        }

        $secret = hash_hmac('sha256', $botToken, 'WebAppData', true);
        $calculatedHash = hash_hmac('sha256', implode("\n", $check), $secret);
        if (!hash_equals($calculatedHash, $receivedHash)) {
            throw new InvalidArgumentException('Telegram init data signature is invalid.');
        }

        $currentTime = $now ?? time();
        $authDate = (int) ($values['auth_date'] ?? 0);
        if ($authDate <= 0 || abs($currentTime - $authDate) > $maxAge) {
            throw new InvalidArgumentException('Telegram init data is expired.');
        }

        $user = json_decode((string) ($values['user'] ?? '{}'), true);
        return is_array($user) ? $user : [];
    }
}
