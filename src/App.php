<?php

declare(strict_types=1);

namespace WolFox\Store;

use WolFox\Store\Delivery\DeliveryService;
use WolFox\Store\Payments\EdfaPayGateway;
use WolFox\Store\Repositories\OrderRepository;
use WolFox\Store\Repositories\ProductRepository;
use WolFox\Store\Services\OrderService;

final class App
{
    public readonly Database $database;
    public readonly ProductRepository $products;
    public readonly OrderRepository $orders;
    public readonly OrderService $orderService;

    public function __construct(?string $databasePath = null)
    {
        $this->database = new Database($databasePath);
        $this->database->migrate();
        $pdo = $this->database->pdo();
        $this->products = new ProductRepository($pdo);
        $this->orders = new OrderRepository($pdo);
        $delivery = new DeliveryService($pdo, $this->orders);
        $this->orderService = new OrderService($this->products, $this->orders, new EdfaPayGateway(), $delivery);
    }
}
