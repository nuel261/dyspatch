<?php
declare(strict_types=1);

/**
 * Public website (https://dyspatch.com.ng) content that admin controls:
 * contact details, social links, app store links. Stored in the `settings`
 * table under `site_*` keys and served to the website by GET /api/site.
 */
final class Website
{
    /** key => [label, type, default, hint]  (type: url|email|text|textarea) */
    public const FIELDS = [
        'Website' => [
            'site_url' => ['Website address', 'url', 'https://dyspatch.com.ng', 'Used for tracking links in SMS, emails, labels and share links.'],
            'site_announcement' => ['Announcement bar', 'text', '', 'Optional one-line notice shown at the top of every page. Leave empty to hide.'],
        ],
        'Contact' => [
            'site_email' => ['General email', 'email', 'info@dyspatch.com.ng', ''],
            'site_partners_email' => ['Partnerships email', 'email', 'partners@dyspatch.com.ng', ''],
            'site_riders_email' => ['Rider support email', 'email', 'riders@dyspatch.com.ng', ''],
            'site_support_email' => ['Customer support email', 'email', 'support@dyspatch.com.ng', 'Shown in the Privacy & Terms page.'],
            'site_business_email' => ['Business support email', 'email', 'business@dyspatch.com.ng', ''],
            'site_hotline' => ['Hotline', 'text', '+234 801 234 5678', 'As it should be displayed, e.g. +234 801 234 5678'],
            'site_address' => ['Registered address', 'textarea', '', 'Shown on the Contact and Privacy & Terms pages.'],
        ],
        'Legal details' => [
            'site_company_name' => ['Registered company name', 'text', '', 'Fills “[Dyspatch Legal Entity Name]” in Privacy & Terms.'],
            'site_rc_number' => ['CAC RC number', 'text', '', 'Digits only, e.g. 1234567'],
            'site_dpo_email' => ['Data protection email', 'email', '', 'Data Protection Officer contact in the Privacy policy.'],
        ],
        'Social' => [
            'site_linkedin' => ['LinkedIn', 'url', '', 'Full profile URL. Empty = hidden.'],
            'site_instagram' => ['Instagram', 'url', '', ''],
            'site_x' => ['X (Twitter)', 'url', '', ''],
        ],
        'App store links' => [
            'site_play_url' => ['Customer app — Google Play', 'url', 'https://play.google.com/store/apps/details?id=com.dyspatch.delivery', ''],
            'site_appstore_url' => ['Customer app — App Store', 'url', '', 'Leave empty until the iOS app is live (the button then points to Google Play).'],
            'site_rider_play_url' => ['Rider app — Google Play', 'url', '', 'Empty = rider buttons use the customer app link.'],
            'site_rider_appstore_url' => ['Rider app — App Store', 'url', '', ''],
        ],
    ];

    public static function flat(): array
    {
        $out = [];
        foreach (self::FIELDS as $fields) $out += $fields;
        return $out;
    }

    /** Settings the public website may read (never secrets). */
    public static function publicSettings(): array
    {
        $out = [];
        foreach (self::flat() as $key => [, , $default]) {
            $out[preg_replace('/^site_/', '', $key)] = (string) Settings::get($key, $default);
        }
        $out['app_name'] = (string) Settings::get('app_name', 'Dyspatch');
        return $out;
    }

    /** Defaults written once so admin sees the current values in the form. */
    public static function seedDefaults(): void
    {
        foreach (self::flat() as $key => [, , $default]) {
            if ($default !== '') DB::query('INSERT IGNORE INTO settings (`key`,`value`) VALUES (?,?)', [$key, $default]);
        }
    }
}
