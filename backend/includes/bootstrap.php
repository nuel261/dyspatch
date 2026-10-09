<?php
declare(strict_types=1);

define('BASE_PATH', dirname(__DIR__));

$configFile = BASE_PATH . '/config/config.php';
if (!file_exists($configFile)) {
    if (basename($_SERVER['SCRIPT_NAME'] ?? '') !== 'install.php') {
        header('Location: ' . (str_contains($_SERVER['SCRIPT_NAME'] ?? '', '/admin/') || str_contains($_SERVER['SCRIPT_NAME'] ?? '', '/api/') ? '../' : '') . 'install.php');
        exit;
    }
}
$GLOBALS['CONFIG'] = file_exists($configFile) ? require $configFile : require BASE_PATH . '/config/config.sample.php';

date_default_timezone_set($GLOBALS['CONFIG']['timezone'] ?? 'Africa/Lagos');

if (($GLOBALS['CONFIG']['env'] ?? 'production') === 'development') {
    ini_set('display_errors', '1');
    error_reporting(E_ALL);
} else {
    ini_set('display_errors', '0');
}
ini_set('log_errors', '1');
ini_set('error_log', BASE_PATH . '/storage/logs/php-error.log');

spl_autoload_register(function (string $class) {
    foreach (['/includes/', '/includes/providers/'] as $dir) {
        $f = BASE_PATH . $dir . $class . '.php';
        if (file_exists($f)) { require_once $f; return; }
    }
});

require_once BASE_PATH . '/includes/helpers.php';
require_once BASE_PATH . '/includes/Providers.php';
