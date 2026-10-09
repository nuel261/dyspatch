<?php
require __DIR__ . '/includes/bootstrap.php';
$p = ($_GET['p'] ?? 'terms') === 'privacy' ? 'privacy' : 'terms';
$name = Settings::get('app_name', 'Dyspatch');
$support = Settings::get('support_email', 'support@dyspatch.com.ng');
?><!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title><?= $p === 'terms' ? 'Terms of Service' : 'Privacy Policy' ?> · <?= e($name) ?></title>
<link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@400;600&display=swap" rel="stylesheet">
<style>body{font-family:Montserrat,sans-serif;max-width:760px;margin:0 auto;padding:32px 16px 60px;color:#0E0F10;line-height:1.7}h1{letter-spacing:-.04em;font-weight:600}h2{font-size:18px;margin-top:28px}p,li{color:#5F6368}a{color:#34A853}@media(prefers-color-scheme:dark){body{background:#0B0D0C;color:#F2F4F5}p,li{color:#A0A4AB}}</style></head><body>
<p><a href="track">← <?= e($name) ?></a></p>
<?php if ($p === 'terms'): ?>
<h1>Terms of Service</h1><p>Last updated <?= date('j F Y') ?>. Replace this page with your lawyer-approved terms before launch.</p>
<h2>The platform</h2><p><?= e($name) ?> connects people who need items delivered with independent riders who use the platform. Riders are independent third-party users, not employees or contractors of <?= e($name) ?>.</p>
<h2>Deliveries</h2><ul><li>Delivery fees are shown before you confirm and charged to your wallet, or collected in cash where offered.</li><li>Handover is secured with a 4-digit code sent to the recipient. Do not share it until the rider is with the recipient.</li><li>Prohibited items include illegal goods, weapons, hazardous materials and live animals.</li></ul>
<h2>Wallet</h2><ul><li>Top-ups are credited after payment is confirmed. Withdrawals requested before the daily cutoff are paid the same business day, otherwise the next business day.</li><li>Cancelled deliveries paid from your wallet are refunded to your wallet.</li></ul>
<h2>Riders</h2><p>Riders must complete identity verification. Accounts may be suspended for violations of these terms, including fraud, safety complaints or repeated failed deliveries.</p>
<h2>Contact</h2><p><a href="mailto:<?= e($support) ?>"><?= e($support) ?></a></p>
<?php else: ?>
<h1>Privacy Policy</h1><p>Last updated <?= date('j F Y') ?>. Replace this page with your lawyer-approved policy before launch.</p>
<h2>What we collect</h2><ul><li>Account details: name, phone number, email, profile photo.</li><li>Delivery details: pickup and drop-off addresses, recipient name and phone, parcel descriptions.</li><li>Location: riders share location while online so customers can track deliveries; customers may share location to set pickup points.</li><li>Payments: wallet transactions and bank account details for withdrawals. Card details are handled by our payment providers.</li><li>Verification documents for riders and businesses.</li></ul>
<h2>How we use it</h2><p>To match deliveries with riders, show live tracking, send SMS, email and push notifications about your deliveries and wallet, prevent fraud, and meet legal obligations.</p>
<h2>Sharing</h2><p>Recipients and people you share a tracking link with can see delivery status, rider first name, vehicle and live location during the delivery. We use service providers for payments, SMS, email, push notifications and identity verification.</p>
<h2>Your choices</h2><p>You can update your profile in the app, turn off push notifications in your device settings, or ask us to delete your account at <a href="mailto:<?= e($support) ?>"><?= e($support) ?></a>.</p>
<?php endif; ?>
</body></html>
