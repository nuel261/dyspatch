<?php
/**
 * Copy this file to config.php and fill in your values.
 * Business rules (pricing, commission, OTP, matching, fees, provider keys)
 * live in the `settings` table and are edited from Admin → Settings — not here.
 */
return [
    'app_url'  => 'https://dyspatch.bitprofil.com',   // no trailing slash
    'env'      => 'production',                        // production | development
    'timezone' => 'Africa/Lagos',

    'db' => [
        'host'    => 'localhost',
        'port'    => 3306,
        'name'    => 'your_db_name',
        'user'    => 'your_db_user',
        'pass'    => 'your_db_password',
        'charset' => 'utf8mb4',
    ],

    // Random 64-char string. Used to sign sessions/webhooks. Generate once and keep secret.
    'app_key' => 'CHANGE_ME_TO_A_LONG_RANDOM_STRING',

    // API bearer tokens lifetime (days)
    'token_ttl_days' => 60,

    // Secret for /cron/run.php?key=... when triggered by URL (cPanel cron can call the CLI instead)
    'cron_key' => 'CHANGE_ME_CRON_KEY',
];
