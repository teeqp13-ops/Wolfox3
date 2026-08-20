<?php

declare(strict_types=1);

use WolFox\Store\Config;

spl_autoload_register(static function (string $class): void {
    $prefix = 'WolFox\\Store\\';
    if (!str_starts_with($class, $prefix)) {
        return;
    }

    $relative = substr($class, strlen($prefix));
    $path = __DIR__ . '/' . str_replace('\\', '/', $relative) . '.php';
    if (is_file($path)) {
        require $path;
    }
});

Config::load(dirname(__DIR__) . '/.env');
date_default_timezone_set(Config::get('APP_TIMEZONE', 'Asia/Riyadh') ?? 'Asia/Riyadh');
