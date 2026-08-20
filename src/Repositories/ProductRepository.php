<?php

declare(strict_types=1);

namespace WolFox\Store\Repositories;

use PDO;

final class ProductRepository
{
    public function __construct(private readonly PDO $pdo)
    {
    }

    public function active(): array
    {
        $statement = $this->pdo->query(
            'SELECT id, slug, name_ar, description_ar, price_halalas, currency, image_url
             FROM products WHERE active = 1 ORDER BY sort_order ASC, id ASC'
        );
        return $statement->fetchAll();
    }

    public function find(int $id): ?array
    {
        $statement = $this->pdo->prepare(
            'SELECT id, slug, name_ar, description_ar, price_halalas, currency, image_url
             FROM products WHERE id = :id AND active = 1 LIMIT 1'
        );
        $statement->execute(['id' => $id]);
        $product = $statement->fetch();
        return $product === false ? null : $product;
    }

    public function upsert(array $product): void
    {
        $statement = $this->pdo->prepare(
            'INSERT INTO products (slug, name_ar, description_ar, price_halalas, currency, image_url, active, sort_order)
             VALUES (:slug, :name_ar, :description_ar, :price_halalas, :currency, :image_url, :active, :sort_order)
             ON CONFLICT(slug) DO UPDATE SET
                name_ar = excluded.name_ar,
                description_ar = excluded.description_ar,
                price_halalas = excluded.price_halalas,
                currency = excluded.currency,
                image_url = excluded.image_url,
                active = excluded.active,
                sort_order = excluded.sort_order,
                updated_at = CURRENT_TIMESTAMP'
        );
        $statement->execute($product);
    }
}
