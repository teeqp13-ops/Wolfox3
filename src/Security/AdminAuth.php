<?php

declare(strict_types=1);

namespace WolFox\Store\Security;

use WolFox\Store\Config;

final class AdminAuth
{
    public static function require(): void
    {
        $expectedUser = Config::get('ADMIN_USER', 'admin') ?? 'admin';
        $passwordHash = Config::get('ADMIN_PASSWORD_HASH', '') ?? '';
        $user = (string) ($_SERVER['PHP_AUTH_USER'] ?? '');
        $password = (string) ($_SERVER['PHP_AUTH_PW'] ?? '');

        if ($passwordHash === '' || !hash_equals($expectedUser, $user) || !password_verify($password, $passwordHash)) {
            header('WWW-Authenticate: Basic realm="WolFox Store"');
            http_response_code($passwordHash === '' ? 503 : 401);
            echo $passwordHash === '' ? 'Admin password is not configured.' : 'Authentication required.';
            exit;
        }
    }
}
