<?php

declare(strict_types=1);

namespace WolFox\Store\Payments;

use InvalidArgumentException;
use RuntimeException;
use WolFox\Store\Config;

final class EdfaPayGateway
{
    public function normalizeCallback(string $rawBody, array $server): array
    {
        $payload = json_decode($rawBody, true);
        if (!is_array($payload)) {
            throw new InvalidArgumentException('Invalid payment callback JSON.');
        }

        $secret = Config::get('EDFAPAY_WEBHOOK_SECRET', '') ?? '';
        $signature = (string) ($server['HTTP_X_EDFAPAY_SIGNATURE'] ?? $server['HTTP_X_SIGNATURE'] ?? '');
        if ($secret !== '') {
            $expectedHex = hash_hmac('sha256', $rawBody, $secret);
            $expectedBase64 = base64_encode(hash_hmac('sha256', $rawBody, $secret, true));
            if ($signature === '' || (!hash_equals($expectedHex, $signature) && !hash_equals($expectedBase64, $signature))) {
                throw new InvalidArgumentException('Invalid payment callback signature.');
            }
        } elseif ((Config::get('APP_ENV', 'production') ?? 'production') === 'production') {
            throw new RuntimeException('EDFAPAY_WEBHOOK_SECRET must be configured in production.');
        }

        $orderNumber = (string) ($payload['order_number'] ?? $payload['merchant_order_id'] ?? $payload['order_id'] ?? '');
        if ($orderNumber === '') {
            throw new InvalidArgumentException('Payment callback has no order number.');
        }

        $providerStatus = strtolower((string) ($payload['status'] ?? $payload['payment_status'] ?? 'pending'));
        $status = match ($providerStatus) {
            'paid', 'success', 'successful', 'completed', 'captured' => 'paid',
            'failed', 'declined', 'cancelled', 'canceled', 'expired' => 'failed',
            default => 'pending',
        };
        $paymentReference = (string) ($payload['transaction_id'] ?? $payload['payment_id'] ?? $payload['reference'] ?? '');
        $eventKey = (string) ($payload['event_id'] ?? $payload['callback_id'] ?? hash('sha256', $rawBody));

        return [
            'event_key' => 'edfapay:' . $eventKey,
            'order_number' => $orderNumber,
            'payment_reference' => $paymentReference !== '' ? $paymentReference : 'edfapay-' . substr($eventKey, 0, 24),
            'provider' => 'edfapay',
            'status' => $status,
            'payload_json' => json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR),
        ];
    }

    public function checkoutState(array $order): array
    {
        $driver = Config::get('PAYMENT_DRIVER', 'mock') ?? 'mock';
        if ($driver === 'mock') {
            return [
                'driver' => 'mock',
                'checkout_url' => '/payment/mock.php?order=' . rawurlencode((string) $order['order_number']),
            ];
        }

        $endpoint = Config::get('EDFAPAY_CHECKOUT_ENDPOINT', '') ?? '';
        if ($endpoint === '' || Config::get('EDFAPAY_MERCHANT_KEY', '') === '' || Config::get('EDFAPAY_PASSWORD', '') === '') {
            return ['driver' => 'edfapay', 'configuration_required' => true];
        }

        return [
            'driver' => 'edfapay',
            'configuration_required' => false,
            'endpoint' => $endpoint,
            'order_number' => $order['order_number'],
            'amount' => number_format(((int) $order['amount_halalas']) / 100, 2, '.', ''),
            'currency' => $order['currency'],
        ];
    }
}
