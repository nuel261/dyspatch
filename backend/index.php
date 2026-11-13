<?php
// Root of app.dyspatch.com.ng/backend. Old tracking links (?id=) go to the public
// website's tracker; everyone else lands on the admin panel.
require __DIR__ . '/includes/bootstrap.php';
if (isset($_GET['id'])) {
    header('Location: ' . site_url('track?id=' . urlencode((string) $_GET['id'])), true, 302);
} else {
    header('Location: admin/', true, 302);
}
exit;
