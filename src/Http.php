<?php

declare(strict_types=1);

namespace WolFox\Store;

final class Http
{
    public static function json(array $payload, int $status = 200): never
    {
        http_response_code($status);
        header('Content-Type: application/json; charset=utf-8');
        header('Cache-Control: no-store');
        echo json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR);
        exit;
    }

    public static function input(): array
    {
        $raw = file_get_contents('php://input') ?: '';
        $input = json_decode($raw, true);
        return is_array($input) ? $input : [];
    }
}
