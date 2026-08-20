<?php

declare(strict_types=1);

namespace WolFox\Store\Repositories;

use PDO;
use RuntimeException;
use Throwable;

final class OrderRepository
{
    public function __construct(private readonly PDO $pdo)
    {
    }

    public function create(array $product, array $customer): array
    {
        $orderNumber = 'WF-' . date('ymd') . '-' . strtoupper(bin2hex(random_bytes(4)));
        $statement = $this->pdo->prepare(
            'INSERT INTO orders
             (order_number, product_id, telegram_user_id, telegram_username, customer_phone, amount_halalas, currency)
             VALUES (:order_number, :product_id, :telegram_user_id, :telegram_username, :customer_phone, :amount_halalas, :currency)'
        );
        $statement->execute([
            'order_number' => $orderNumber,
            'product_id' => $product['id'],
            'telegram_user_id' => $customer['telegram_user_id'] ?? null,
            'telegram_username' => $customer['telegram_username'] ?? null,
            'customer_phone' => $customer['customer_phone'] ?? null,
            'amount_halalas' => $product['price_halalas'],
            'currency' => $product['currency'],
        ]);

        return $this->findByNumber($orderNumber) ?? throw new RuntimeException('Unable to create order.');
    }

    public function findByNumber(string $orderNumber): ?array
    {
        $statement = $this->pdo->prepare($this->detailsSql() . ' WHERE o.order_number = :order_number LIMIT 1');
        $statement->execute(['order_number' => $orderNumber]);
        $order = $statement->fetch();
        return $order === false ? null : $order;
    }

    public function recent(int $limit = 50): array
    {
        $statement = $this->pdo->prepare($this->detailsSql() . ' ORDER BY o.id DESC LIMIT :limit');
        $statement->bindValue(':limit', $limit, PDO::PARAM_INT);
        $statement->execute();
        return $statement->fetchAll();
    }

    public function applyPaymentEvent(array $event): array
    {
        $this->pdo->beginTransaction();
        try {
            $existing = $this->pdo->prepare('SELECT order_id FROM payment_events WHERE event_key = :event_key LIMIT 1');
            $existing->execute(['event_key' => $event['event_key']]);
            $existingOrderId = $existing->fetchColumn();
            if ($existingOrderId !== false) {
                $this->pdo->commit();
                return $this->findById((int) $existingOrderId) ?? throw new RuntimeException('Stored payment event has no order.');
            }

            $order = $this->findByNumber($event['order_number']);
            if ($order === null) {
                throw new RuntimeException('Order not found.');
            }

            $insertEvent = $this->pdo->prepare(
                'INSERT INTO payment_events (event_key, order_id, provider, status, payload_json)
                 VALUES (:event_key, :order_id, :provider, :status, :payload_json)'
            );
            $insertEvent->execute([
                'event_key' => $event['event_key'],
                'order_id' => $order['id'],
                'provider' => $event['provider'],
                'status' => $event['status'],
                'payload_json' => $event['payload_json'],
            ]);

            if ($event['status'] === 'paid' && $order['status'] !== 'paid') {
                $code = $this->allocateCode((int) $order['product_id'], (int) $order['id']);
                $paid = $this->pdo->prepare(
                    'UPDATE orders SET status = :status, payment_reference = :payment_reference,
                     license_code_id = :license_code_id, paid_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
                     WHERE id = :id'
                );
                $paid->execute([
                    'status' => 'paid',
                    'payment_reference' => $event['payment_reference'],
                    'license_code_id' => $code['id'] ?? null,
                    'id' => $order['id'],
                ]);
            } elseif ($event['status'] === 'failed' && $order['status'] === 'pending') {
                $failed = $this->pdo->prepare('UPDATE orders SET status = :status, updated_at = CURRENT_TIMESTAMP WHERE id = :id');
                $failed->execute(['status' => 'failed', 'id' => $order['id']]);
            }

            $this->pdo->commit();
            return $this->findById((int) $order['id']) ?? throw new RuntimeException('Order disappeared after payment update.');
        } catch (Throwable $error) {
            if ($this->pdo->inTransaction()) {
                $this->pdo->rollBack();
            }
            throw $error;
        }
    }

    public function markCodeDelivered(int $orderId): void
    {
        $statement = $this->pdo->prepare(
            'UPDATE license_codes SET status = :status, delivered_at = CURRENT_TIMESTAMP
             WHERE id = (SELECT license_code_id FROM orders WHERE id = :order_id)'
        );
        $statement->execute(['status' => 'delivered', 'order_id' => $orderId]);
    }

    private function allocateCode(int $productId, int $orderId): ?array
    {
        $statement = $this->pdo->prepare(
            "SELECT id, code FROM license_codes WHERE product_id = :product_id AND status = 'available' ORDER BY id ASC LIMIT 1"
        );
        $statement->execute(['product_id' => $productId]);
        $code = $statement->fetch();
        if ($code === false) {
            return null;
        }

        $reserve = $this->pdo->prepare(
            "UPDATE license_codes SET status = 'reserved', reserved_order_id = :order_id
             WHERE id = :id AND status = 'available'"
        );
        $reserve->execute(['order_id' => $orderId, 'id' => $code['id']]);
        if ($reserve->rowCount() !== 1) {
            throw new RuntimeException('The selected license code was reserved concurrently.');
        }
        return $code;
    }

    private function findById(int $id): ?array
    {
        $statement = $this->pdo->prepare($this->detailsSql() . ' WHERE o.id = :id LIMIT 1');
        $statement->execute(['id' => $id]);
        $order = $statement->fetch();
        return $order === false ? null : $order;
    }

    private function detailsSql(): string
    {
        return 'SELECT o.*, p.name_ar AS product_name, p.slug AS product_slug, c.code AS license_code
                FROM orders o
                INNER JOIN products p ON p.id = o.product_id
                LEFT JOIN license_codes c ON c.id = o.license_code_id';
    }
}
