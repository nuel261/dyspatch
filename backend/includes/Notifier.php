<?php
declare(strict_types=1);

/** One call → in-app notification + push + email. */
final class Notifier
{
    public static function notify(string $ownerType, int $ownerId, string $category, string $title, string $body, array $data = [], array $email = []): void
    {
        DB::insert('notifications', [
            'owner_type' => $ownerType, 'owner_id' => $ownerId, 'category' => $category,
            'title' => $title, 'body' => $body, 'data' => $data ? json_encode($data) : null,
        ]);
        try { Push::toOwner($ownerType, $ownerId, $title, $body, $data + ['category' => $category]); }
        catch (Throwable $e) { log_line('push', $e->getMessage()); }

        $table = $ownerType === 'rider' ? 'riders' : 'users';
        $to = DB::value("SELECT email FROM $table WHERE id = ?", [$ownerId]);
        if ($to && ($email['send'] ?? true)) {
            $html = Mailer::template($email['heading'] ?? $title, $email['html'] ?? nl2br(e($body)), $email['cta_label'] ?? null, $email['cta_url'] ?? null, $email['code'] ?? null);
            Mailer::send((string) $to, $email['subject'] ?? $title . ' · Dyspatch', $html);
        }
    }

    public static function adminAlert(string $subject, string $html, ?string $ctaUrl = null): void
    {
        $to = (string) Settings::get('admin_alert_email', '');
        if ($to === '') return;
        foreach (array_filter(array_map('trim', explode(',', $to))) as $addr) {
            Mailer::send($addr, "[Dyspatch Admin] $subject", Mailer::template($subject, $html, $ctaUrl ? 'Open in admin' : null, $ctaUrl));
        }
    }

    /** Standard customer-facing messages for each order status. */
    public static function orderStatus(array $order, string $status): void
    {
        $tid = $order['track_id'];
        $rider = $order['rider_id'] ? DB::row('SELECT first_name, last_name, plate FROM riders WHERE id = ?', [$order['rider_id']]) : null;
        $riderName = $rider ? trim($rider['first_name'] . ' ' . $rider['last_name']) : 'Your rider';
        $map = [
            'matched'   => ['Rider assigned', "$riderName is heading to pick up $tid."],
            'picked_up' => ['Pickup completed', "Your package $tid has been picked up."],
            'en_route'  => ['On the way', "$riderName is on the way to the drop-off with $tid."],
            'arrived'   => ['Rider has arrived', "$riderName has arrived at the drop-off for $tid. Share the delivery code with the recipient."],
            'delivered' => ['Delivered', "Package $tid was delivered successfully."],
            'cancelled' => ['Delivery cancelled', "Delivery $tid was cancelled." . ($order['cancel_reason'] ? ' Reason: ' . $order['cancel_reason'] : '')],
            'failed'    => ['Delivery issue', "We couldn't complete delivery $tid. Our team will reach out."],
            'pending'   => ['Delivery created', "We're matching $tid with a nearby rider."],
        ];
        if (!isset($map[$status]) || !$order['user_id']) return;
        [$title, $body] = $map[$status];
        $trackUrl = app_url('track?id=' . urlencode($tid));
        self::notify('user', (int) $order['user_id'], 'delivery', $title, $body,
            ['type' => 'order', 'order_id' => (string) $order['id'], 'track_id' => $tid, 'status' => $status],
            ['heading' => $title, 'html' => '<p>' . e($body) . '</p><p style="margin:0">Track ID: <b style="color:#0E0F10">' . e($tid) . '</b></p>', 'cta_label' => 'Track package', 'cta_url' => $trackUrl]);
    }
}
