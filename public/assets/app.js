(() => {
    const root = document.documentElement;
    const telegram = window.Telegram?.WebApp;
    const savedTheme = localStorage.getItem('wolfox-theme');
    const preferredTheme = savedTheme || (telegram?.colorScheme === 'light' ? 'light' : 'dark');
    root.dataset.theme = preferredTheme;
    telegram?.ready();
    telegram?.expand();

    document.querySelector('#themeToggle')?.addEventListener('click', () => {
        const next = root.dataset.theme === 'dark' ? 'light' : 'dark';
        root.dataset.theme = next;
        localStorage.setItem('wolfox-theme', next);
    });

    const dialog = document.querySelector('#checkoutDialog');
    const form = document.querySelector('#checkoutForm');
    const productId = document.querySelector('#selectedProduct');
    const productTitle = document.querySelector('#checkoutProduct');
    const message = document.querySelector('#checkoutMessage');

    document.querySelectorAll('.buy-button').forEach((button) => {
        button.addEventListener('click', () => {
            productId.value = button.dataset.productId;
            productTitle.textContent = button.dataset.productName;
            message.textContent = '';
            dialog.showModal();
        });
    });

    form?.addEventListener('submit', async (event) => {
        event.preventDefault();
        message.textContent = 'جارٍ إنشاء الطلب…';
        const submit = form.querySelector('[type="submit"]');
        submit.disabled = true;
        try {
            const response = await fetch('/api/orders.php', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({
                    product_id: Number(productId.value),
                    phone: document.querySelector('#customerPhone').value,
                    init_data: telegram?.initData || ''
                })
            });
            const payload = await response.json();
            if (!response.ok) throw new Error(payload.error || 'تعذر إنشاء الطلب.');
            message.textContent = `تم إنشاء الطلب ${payload.order.order_number}`;
            if (payload.payment.checkout_url) {
                window.location.assign(payload.payment.checkout_url);
            } else if (payload.payment.configuration_required) {
                message.textContent += ' — يلزم إكمال إعداد بوابة الدفع.';
            }
        } catch (error) {
            message.textContent = error.message;
        } finally {
            submit.disabled = false;
        }
    });
})();
