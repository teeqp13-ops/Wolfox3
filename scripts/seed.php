<?php

declare(strict_types=1);

use WolFox\Store\App;

require dirname(__DIR__) . '/src/bootstrap.php';

$app = new App();
$products = [
    [
        'slug' => 'gps-plus-day',
        'name_ar' => 'GPS Plus — يوم واحد',
        'description_ar' => 'تفعيل رقمي لمدة يوم واحد مع تسليم آلي بعد الدفع.',
        'price_halalas' => 1500,
        'currency' => 'SAR',
        'image_url' => '',
        'active' => 1,
        'sort_order' => 10,
    ],
    [
        'slug' => 'gps-plus-month',
        'name_ar' => 'GPS Plus — شهر',
        'description_ar' => 'اشتراك شهر كامل ودعم التسليم عبر Telegram أو WhatsApp.',
        'price_halalas' => 6900,
        'currency' => 'SAR',
        'image_url' => '',
        'active' => 1,
        'sort_order' => 20,
    ],
    [
        'slug' => 'gps-plus-quarter',
        'name_ar' => 'GPS Plus — ثلاثة أشهر',
        'description_ar' => 'باقة ممتدة لمدة ثلاثة أشهر بسعر موفر.',
        'price_halalas' => 17900,
        'currency' => 'SAR',
        'image_url' => '',
        'active' => 1,
        'sort_order' => 30,
    ],
];

foreach ($products as $product) {
    $app->products->upsert($product);
}

fwrite(STDOUT, count($products) . " products seeded.\n");
