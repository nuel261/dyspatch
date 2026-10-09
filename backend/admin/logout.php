<?php
require __DIR__ . '/_init.php';
if ($a = admin()) audit((int) $a['id'], 'logout');
$_SESSION = [];
session_destroy();
redirect('login.php');
