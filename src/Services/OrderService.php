<?php

declare(strict_types=1);

namespace WolFox\Store\Services;

use InvalidArgumentException;
use WolFox\Store\Delivery\DeliveryService;
use WolFox\Store\Payments\EdfaPayGateway;
use WolFox\Store\Repositories\OrderRepository;
use WolFox\Store\Repositories\ProductRepository;

final class OrderService
{
    public function __construct(
        private readonly ProductRepository $products,
        private readonly OrderRepository $orders,
        private readonly EdfaPayGateway $payments,
        private readonly DeliveryService $delivery,
    ) {
    }

    public function create(int $productId, array $customer): array
    {
        $product = $this->products->find($productId);
        if ($product === null) {
            throw new InvalidArgumentException('المنتج غير موجود أو غير متاح.');
        }
        $order = $this->orders->create($product, $customer);
        return ['order' => $order, 'payment' => $this->payments->checkoutState($order)];
    }

    public function handlePayment(string $rawBody, array $server): array
    {
        $event = $this->payments->normalizeCallback($rawBody, $server);
        $order = $this->orders->applyPaymentEvent($event);
        $delivery = $this->delivery->deliver($order);
        return ['order' => $order, 'delivery' => $delivery];
    }
}
