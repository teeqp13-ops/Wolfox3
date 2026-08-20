<?php

declare(strict_types=1);

use WolFox\Store\App;

require dirname(__DIR__) . '/src/bootstrap.php';

[$script, $slug, $file] = array_pad($argv, 3, null);
if (!$slug || !$file || !is_file($file)) {
    fwrite(STDERR, "Usage: php scripts/import_codes.php <product-slug> <codes.txt>\n");
    exit(1);
}

$app = new App();
$pdo = $app->database->pdo();
$product = $pdo->prepare('SELECT id FROM products WHERE slug = :slug LIMIT 1');
$product->execute(['slug' => $slug]);
$productId = $product->fetchColumn();
if ($productId === false) {
    fwrite(STDERR, "Product not found: {$slug}\n");
    exit(1);
}

$insert = $pdo->prepare('INSERT OR IGNORE INTO license_codes (product_id, code) VALUES (:product_id, :code)');
$imported = 0;
$pdo->beginTransaction();
foreach (file($file, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) ?: [] as $line) {
    $code = trim($line);
    if ($code === '') {
        continue;
    }
    $insert->execute(['product_id' => $productId, 'code' => $code]);
    $imported += $insert->rowCount();
}
$pdo->commit();

fwrite(STDOUT, "Imported {$imported} new codes for {$slug}.\n");
