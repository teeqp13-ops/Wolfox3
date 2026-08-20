<?php

declare(strict_types=1);

namespace WolFox\Store;

use RuntimeException;

final class HttpClient
{
    public static function postJson(string $url, array $payload, array $headers = []): array
    {
        $body = json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR);
        $headers = array_merge(['Content-Type: application/json'], $headers);

        if (function_exists('curl_init')) {
            $handle = curl_init($url);
            curl_setopt_array($handle, [
                CURLOPT_POST => true,
                CURLOPT_POSTFIELDS => $body,
                CURLOPT_HTTPHEADER => $headers,
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_CONNECTTIMEOUT => 8,
                CURLOPT_TIMEOUT => 20,
            ]);
            $response = curl_exec($handle);
            $status = (int) curl_getinfo($handle, CURLINFO_RESPONSE_CODE);
            $error = curl_error($handle);
            curl_close($handle);
            if ($response === false || $status < 200 || $status >= 300) {
                throw new RuntimeException('HTTP request failed: ' . ($error !== '' ? $error : 'status ' . $status));
            }
        } else {
            $context = stream_context_create(['http' => [
                'method' => 'POST',
                'header' => implode("\r\n", $headers),
                'content' => $body,
                'timeout' => 20,
                'ignore_errors' => true,
            ]]);
            $response = file_get_contents($url, false, $context);
            if ($response === false) {
                throw new RuntimeException('HTTP request failed.');
            }
        }

        $decoded = json_decode((string) $response, true);
        return is_array($decoded) ? $decoded : ['raw' => (string) $response];
    }
}
