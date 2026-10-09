<?php
// Root of dyspatch.bitprofil.com — send visitors to public tracking (admins use /admin).
header('Location: track' . (isset($_GET['id']) ? '?id=' . urlencode((string) $_GET['id']) : ''), true, 302);
exit;
