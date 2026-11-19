<?php
declare(strict_types=1);

final class Geo
{
    /** Zone containing the point (polygon if defined, else radius). Live and gated zones both returned; caller checks is_live. */
    public static function zoneFor(?float $lat, ?float $lng): ?array
    {
        if ($lat === null || $lng === null) return null;
        $best = null;
        foreach (DB::all('SELECT * FROM zones ORDER BY is_live DESC, radius_km ASC') as $z) {
            $poly = $z['polygon'] ? json_decode($z['polygon'], true) : null;
            $inside = is_array($poly) && count($poly) >= 3
                ? point_in_polygon($lat, $lng, $poly)
                : haversine_km($lat, $lng, (float) $z['center_lat'], (float) $z['center_lng']) <= (float) $z['radius_km'];
            if ($inside) { $best = $z; break; }
        }
        return $best;
    }

    /** Address autocomplete. Google Places when a key is set, OpenStreetMap otherwise. */
    public static function search(string $q, ?float $lat = null, ?float $lng = null): array
    {
        $q = trim($q);
        if (mb_strlen($q) < 2) return [];
        $key = Settings::get('google_maps_key');
        if ($key) {
            $url = 'https://maps.googleapis.com/maps/api/place/textsearch/json?region=ng&query=' . rawurlencode($q) . '&key=' . rawurlencode($key);
            if ($lat !== null && $lng !== null) $url .= "&location=$lat,$lng&radius=30000";
            $r = http_request('GET', $url);
            return array_slice(array_map(fn($p) => [
                'name' => $p['name'], 'address' => $p['formatted_address'] ?? $p['name'],
                'lat' => $p['geometry']['location']['lat'], 'lng' => $p['geometry']['location']['lng'],
            ], $r['json']['results'] ?? []), 0, 8);
        }
        $url = 'https://nominatim.openstreetmap.org/search?format=jsonv2&addressdetails=1&limit=8&countrycodes=ng&q=' . rawurlencode($q);
        $rows = [];
        if ($lat !== null && $lng !== null) {
            // Look inside the service area first; only widen to all of Nigeria if nothing matches.
            $d = 0.4;
            $box = '&viewbox=' . ($lng - $d) . ',' . ($lat + $d) . ',' . ($lng + $d) . ',' . ($lat - $d);
            $rows = http_request('GET', $url . $box . '&bounded=1', ['Accept-Language' => 'en'])['json'] ?? [];
            if (!$rows) $rows = http_request('GET', $url . $box, ['Accept-Language' => 'en'])['json'] ?? [];
        } else {
            $rows = http_request('GET', $url, ['Accept-Language' => 'en'])['json'] ?? [];
        }
        return array_map(function ($p) {
            $a = $p['address'] ?? [];
            $sub = implode(', ', array_filter([$a['suburb'] ?? $a['road'] ?? null, $a['city'] ?? $a['town'] ?? $a['county'] ?? null, $a['state'] ?? null]));
            return ['name' => $p['name'] ?: explode(',', $p['display_name'])[0], 'address' => $sub ?: $p['display_name'],
                'full_address' => $p['display_name'], 'lat' => (float) $p['lat'], 'lng' => (float) $p['lon']];
        }, $rows);
    }

    /** Where suggestions are biased (Admin → Settings; defaults to Benin City). */
    private static function bias(): array
    {
        return [Settings::float('places_bias_lat', 6.3350), Settings::float('places_bias_lng', 5.6037),
            max(1000, min(50000, Settings::int('places_bias_radius_m', 30000)))];
    }

    /**
     * Google Places Autocomplete (New): Nigeria only, biased to the service city,
     * billed per session when the app passes the same session token to details().
     * Without a Google key, falls back to OpenStreetMap results (which already carry coordinates).
     * Each result: place_id (null for OSM), name, address, and lat/lng only when already known.
     */
    public static function autocomplete(string $q, ?string $session = null): array
    {
        $q = trim($q);
        if (mb_strlen($q) < 2) return [];
        $key = Settings::get('google_maps_key');
        if (!$key) {
            [$lat, $lng] = self::bias();
            return array_map(fn($p) => $p + ['place_id' => null], self::search($q, $lat, $lng));
        }
        [$lat, $lng, $radius] = self::bias();
        $body = ['input' => $q, 'includedRegionCodes' => ['ng'], 'regionCode' => 'ng', 'languageCode' => 'en',
            'locationBias' => ['circle' => ['center' => ['latitude' => $lat, 'longitude' => $lng], 'radius' => (float) $radius]],
            'origin' => ['latitude' => $lat, 'longitude' => $lng]];
        if ($session = self::cleanSession($session)) $body['sessionToken'] = $session;
        $r = http_request('POST', 'https://places.googleapis.com/v1/places:autocomplete', ['X-Goog-Api-Key' => $key], $body, 8);
        if (($r['status'] ?? 0) !== 200) {
            log_line('places', 'autocomplete ' . ($r['status'] ?? 0) . ' ' . mb_substr((string) ($r['body'] ?? ''), 0, 300));
            return [];
        }
        $out = [];
        foreach ($r['json']['suggestions'] ?? [] as $s) {
            $p = $s['placePrediction'] ?? null;
            if (!$p) continue;
            $out[] = ['place_id' => $p['placeId'],
                'name' => $p['structuredFormat']['mainText']['text'] ?? $p['text']['text'] ?? '',
                'address' => $p['structuredFormat']['secondaryText']['text'] ?? '',
                'distance_m' => $p['distanceMeters'] ?? null];
        }
        return $out;
    }

    /** Place Details (New): coordinates + full address for one autocomplete pick; closes the session. */
    public static function details(string $placeId, ?string $session = null): ?array
    {
        $key = Settings::get('google_maps_key');
        if (!$key || !preg_match('/^[A-Za-z0-9_-]{10,300}$/', $placeId)) return null;
        $url = 'https://places.googleapis.com/v1/places/' . rawurlencode($placeId) . '?languageCode=en&regionCode=ng';
        if ($session = self::cleanSession($session)) $url .= '&sessionToken=' . rawurlencode($session);
        $r = http_request('GET', $url, ['X-Goog-Api-Key' => $key, 'X-Goog-FieldMask' => 'id,displayName,formattedAddress,location'], null, 8);
        $j = $r['json'] ?? null;
        if (($r['status'] ?? 0) !== 200 || !isset($j['location'])) {
            log_line('places', 'details ' . ($r['status'] ?? 0) . ' ' . mb_substr((string) ($r['body'] ?? ''), 0, 300));
            return null;
        }
        return ['place_id' => $j['id'] ?? $placeId, 'name' => $j['displayName']['text'] ?? '',
            'address' => $j['formattedAddress'] ?? '', 'lat' => (float) $j['location']['latitude'], 'lng' => (float) $j['location']['longitude']];
    }

    private static function cleanSession(?string $s): ?string
    {
        $s = trim((string) $s);
        return preg_match('/^[A-Za-z0-9_-]{8,64}$/', $s) ? $s : null;
    }

    public static function reverse(float $lat, float $lng): ?string
    {
        $key = Settings::get('google_maps_key');
        if ($key) {
            $r = http_request('GET', "https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=" . rawurlencode($key));
            return $r['json']['results'][0]['formatted_address'] ?? null;
        }
        $r = http_request('GET', "https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lng", ['Accept-Language' => 'en']);
        return $r['json']['display_name'] ?? null;
    }

    /** Road distance (km) + duration (min). Google → OSRM → haversine × road factor. */
    public static function route(float $aLat, float $aLng, float $bLat, float $bLng): array
    {
        $key = Settings::get('google_maps_key');
        if ($key) {
            $r = http_request('GET', "https://maps.googleapis.com/maps/api/distancematrix/json?origins=$aLat,$aLng&destinations=$bLat,$bLng&mode=driving&key=" . rawurlencode($key), [], null, 8);
            $el = $r['json']['rows'][0]['elements'][0] ?? null;
            if (($el['status'] ?? '') === 'OK') return ['km' => round($el['distance']['value'] / 1000, 2), 'minutes' => (int) ceil($el['duration']['value'] / 60)];
        }
        $r = http_request('GET', "https://router.project-osrm.org/route/v1/driving/$aLng,$aLat;$bLng,$bLat?overview=false", [], null, 6);
        if (isset($r['json']['routes'][0])) {
            return ['km' => round($r['json']['routes'][0]['distance'] / 1000, 2), 'minutes' => (int) ceil($r['json']['routes'][0]['duration'] / 60)];
        }
        $km = round(haversine_km($aLat, $aLng, $bLat, $bLng) * Settings::float('road_factor', 1.3), 2);
        return ['km' => $km, 'minutes' => self::etaMinutes($km)];
    }

    public static function etaMinutes(float $km): int
    {
        return max(2, (int) ceil($km / max(5, Settings::float('avg_speed_kmh', 25)) * 60));
    }
}
