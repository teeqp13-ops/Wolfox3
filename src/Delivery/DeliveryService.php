<?php

declare(strict_types=1);

namespace WolFox\Store\Delivery;

use PDO;
use Throwable;
use WolFox\Store\Config;
use WolFox\Store\HttpClient;
use WolFox\Store\Repositories\OrderRepository;

final class DeliveryService
{
    public function __construct(
        private readonly PDO $pdo,
        private readonly OrderRepository $orders,
    ) {
    }

    public function deliver(array $order): array
    {
        if (($order['status'] ?? '') !== 'paid' || empty($order['license_code'])) {
            return ['sent' => false, 'reason' => 'awaiting_paid_order_or_code'];
        }

        $message = "طلبك من متجر ولفوكس جاهز ✅\n"
            . "رقم الطلب: {$order['order_number']}\n"
            . "المنتج: {$order['product_name']}\n"
            . "كود التفعيل: {$order['license_code']}\n"
            . 'احتفظ بالكود ولا تشاركه مع الآخرين.';

        $results = [];
        if (!empty($order['telegram_user_id']) && (Config::get('TELEGRAM_BOT_TOKEN', '') ?? '') !== '') {
            $results['telegram'] = $this->sendTelegram((string) $order['telegram_user_id'], $message, (int) $order['id']);
        }
        if (!empty($order['customer_phone']) && Config::bool('NERACHAT_ENABLED')) {
            $results['whatsapp'] = $this->sendWhatsApp((string) $order['customer_phone'], $message, (int) $order['id']);
        }

        $sent = in_array(true, array_column($results, 'sent'), true);
        if ($sent) {
            $this->orders->markCodeDelivered((int) $order['id']);
        }
        return ['sent' => $sent, 'channels' => $results];
    }

    private function sendTelegram(string $chatId, string $message, int $orderId): array
    {
        $token = Config::get('TELEGRAM_BOT_TOKEN', '') ?? '';
        return $this->attempt($orderId, 'telegram', $chatId, static fn (): array => HttpClient::postJson(
            'https://api.telegram.org/bot' . rawurlencode($token) . '/sendMessage',
            ['chat_id' => $chatId, 'text' => $message]
        ));
    }

    private function sendWhatsApp(string $phone, string $message, int $orderId): array
    {
        $url = Config::get('NERACHAT_API_URL', '') ?? '';
        $token = Config::get('NERACHAT_API_TOKEN', '') ?? '';
        return $this->attempt($orderId, 'whatsapp', $phone, static fn (): array => HttpClient::postJson(
            $url,
            ['phone' => $phone, 'message' => $message],
            ['Authorization: Bearer ' . $token]
        ));
    }

    private function attempt(int $orderId, string $channel, string $destination, callable $sender): array
    {
        $upsert = $this->pdo->prepare(
            "INSERT INTO deliveries (order_id, channel, destination, status, attempts)
             VALUES (:order_id, :channel, :destination, 'pending', 0)
             ON CONFLICT(order_id, channel) DO UPDATE SET destination = excluded.destination, updated_at = CURRENT_TIMESTAMP"
        );
        $upsert->execute(['order_id' => $orderId, 'channel' => $channel, 'destination' => $destination]);

        try {
            $response = $sender();
            $status = 'sent';
            $sent = true;
        } catch (Throwable $error) {
            $response = ['error' => $error->getMessage()];
            $status = 'failed';
            $sent = false;
        }

        $update = $this->pdo->prepare(
            'UPDATE deliveries SET status = :status, provider_response = :response,
             attempts = attempts + 1, updated_at = CURRENT_TIMESTAMP
             WHERE order_id = :order_id AND channel = :channel'
        );
        $update->execute([
            'status' => $status,
            'response' => json_encode($response, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
            'order_id' => $orderId,
            'channel' => $channel,
        ]);
        return ['sent' => $sent, 'status' => $status];
    }
}
