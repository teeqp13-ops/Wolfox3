<?php

declare(strict_types=1);

use WolFox\Store\App;
use WolFox\Store\Config;

require dirname(__DIR__) . '/src/bootstrap.php';

$app = new App();
$products = $app->products->active();
$currency = Config::get('APP_CURRENCY', 'SAR') ?? 'SAR';

function h(string $value): string
{
    return htmlspecialchars($value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}
?>
<!doctype html>
<html lang="ar" dir="rtl" data-theme="dark">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <meta name="theme-color" content="#07111f">
    <title>متجر ولفوكس</title>
    <link rel="stylesheet" href="/assets/app.css?v=1">
    <script src="https://telegram.org/js/telegram-web-app.js"></script>
    <script defer src="/assets/app.js?v=1"></script>
</head>
<body>
<header class="topbar">
    <div>
        <span class="eyebrow">WOLFOX STORE</span>
        <h1>متجر ولفوكس</h1>
    </div>
    <button class="icon-button" id="themeToggle" type="button" aria-label="تغيير المظهر">◐</button>
</header>

<main>
    <section class="hero">
        <div>
            <span class="status-dot"></span>
            تسليم رقمي آلي بعد تأكيد الدفع
        </div>
        <h2>منتجاتك الرقمية،<br><strong>بسرعة وأمان.</strong></h2>
        <p>اختر المنتج، أكمل الدفع، واستلم كود التفعيل عبر Telegram أو WhatsApp.</p>
    </section>

    <section class="products" aria-labelledby="productsTitle">
        <div class="section-heading">
            <h2 id="productsTitle">المنتجات</h2>
            <span><?= count($products) ?> متاح</span>
        </div>

        <div class="product-grid">
            <?php foreach ($products as $product): ?>
                <article class="product-card">
                    <div class="product-icon" aria-hidden="true">WF</div>
                    <div class="product-copy">
                        <span class="badge">تفعيل فوري</span>
                        <h3><?= h((string) $product['name_ar']) ?></h3>
                        <p><?= h((string) $product['description_ar']) ?></p>
                    </div>
                    <div class="product-footer">
                        <div class="price">
                            <strong><?= number_format(((int) $product['price_halalas']) / 100, 2) ?></strong>
                            <span><?= h((string) ($product['currency'] ?: $currency)) ?></span>
                        </div>
                        <button class="buy-button" type="button" data-product-id="<?= (int) $product['id'] ?>" data-product-name="<?= h((string) $product['name_ar']) ?>">
                            شراء الآن
                        </button>
                    </div>
                </article>
            <?php endforeach; ?>
        </div>
    </section>
</main>

<dialog id="checkoutDialog">
    <form method="dialog" id="checkoutForm">
        <div class="dialog-head">
            <div>
                <span class="eyebrow">إتمام الطلب</span>
                <h2 id="checkoutProduct">المنتج</h2>
            </div>
            <button class="icon-button" value="cancel" aria-label="إغلاق">×</button>
        </div>
        <label>
            رقم WhatsApp للتسليم الاحتياطي
            <input id="customerPhone" name="phone" inputmode="tel" autocomplete="tel" placeholder="9665XXXXXXXX" dir="ltr">
        </label>
        <input id="selectedProduct" type="hidden" name="product_id">
        <p class="form-note">لن يتم احتساب السعر من جهازك؛ السعر يُثبت من قاعدة بيانات المتجر.</p>
        <button class="primary-button" type="submit">إنشاء الطلب والمتابعة للدفع</button>
        <p id="checkoutMessage" class="message" role="status"></p>
    </form>
</dialog>

<footer>
    <span>© <?= date('Y') ?> WolFox</span>
    <a href="/admin/">الإدارة</a>
</footer>
</body>
</html>
