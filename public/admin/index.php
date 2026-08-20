<?php

declare(strict_types=1);

use WolFox\Store\App;
use WolFox\Store\Security\AdminAuth;

require dirname(__DIR__, 2) . '/src/bootstrap.php';

AdminAuth::require();
$app = new App();
$orders = $app->orders->recent(100);
$counts = ['pending' => 0, 'paid' => 0, 'failed' => 0];
foreach ($orders as $order) {
    if (isset($counts[$order['status']])) {
        $counts[$order['status']]++;
    }
}

function adminH(string $value): string
{
    return htmlspecialchars($value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}
?>
<!doctype html>
<html lang="ar" dir="rtl" data-theme="dark">
<head>
    <meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
    <title>إدارة متجر ولفوكس</title>
    <link rel="stylesheet" href="/assets/app.css?v=1">
    <style>
        .admin{width:min(1180px,calc(100% - 24px));margin:30px auto}.stats{display:grid;grid-template-columns:repeat(3,1fr);gap:14px}.stat,.table-wrap{border:1px solid var(--line);border-radius:20px;background:var(--surface);padding:20px}.stat strong{display:block;font-size:2rem;color:var(--blue-2)}.table-wrap{margin-top:20px;overflow:auto}table{width:100%;border-collapse:collapse;min-width:850px}th,td{text-align:right;padding:13px;border-bottom:1px solid var(--line);white-space:nowrap}th{color:var(--muted)}.status{padding:5px 8px;border-radius:99px;background:var(--surface-2)}@media(max-width:600px){.stats{grid-template-columns:1fr}}
    </style>
</head>
<body><main class="admin">
    <div class="section-heading"><div><span class="eyebrow">WOLFOX ADMIN</span><h1>لوحة الطلبات</h1></div><a href="/">عرض المتجر</a></div>
    <section class="stats">
        <article class="stat"><span>بانتظار الدفع</span><strong><?= $counts['pending'] ?></strong></article>
        <article class="stat"><span>مدفوع</span><strong><?= $counts['paid'] ?></strong></article>
        <article class="stat"><span>فشل</span><strong><?= $counts['failed'] ?></strong></article>
    </section>
    <section class="table-wrap"><table>
        <thead><tr><th>الطلب</th><th>المنتج</th><th>الحالة</th><th>المبلغ</th><th>Telegram</th><th>WhatsApp</th><th>الكود</th><th>التاريخ</th></tr></thead>
        <tbody><?php foreach ($orders as $order): ?><tr>
            <td><?= adminH((string) $order['order_number']) ?></td>
            <td><?= adminH((string) $order['product_name']) ?></td>
            <td><span class="status"><?= adminH((string) $order['status']) ?></span></td>
            <td><?= number_format(((int) $order['amount_halalas']) / 100, 2) ?> <?= adminH((string) $order['currency']) ?></td>
            <td><?= adminH((string) ($order['telegram_username'] ?: $order['telegram_user_id'] ?: '—')) ?></td>
            <td><?= adminH((string) ($order['customer_phone'] ?: '—')) ?></td>
            <td><?= adminH((string) ($order['license_code'] ?: 'بانتظار المخزون')) ?></td>
            <td><?= adminH((string) $order['created_at']) ?></td>
        </tr><?php endforeach; ?></tbody>
    </table></section>
</main></body></html>
