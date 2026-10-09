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
        if ($lat !== null && $lng !== null) {
            $d = 0.4;
            $url .= '&viewbox=' . ($lng - $d) . ',' . ($lat + $d) . ',' . ($lng + $d) . ',' . ($lat - $d);
        }
        $r = http_request('GET', $url, ['Accept-Language' => 'en']);
        return array_map(function ($p) {
            $a = $p['address'] ?? [];
            $sub = implode(', ', array_filter([$a['suburb'] ?? $a['road'] ?? null, $a['city'] ?? $a['town'] ?? $a['county'] ?? null, $a['state'] ?? null]));
            return ['name' => $p['name'] ?: explode(',', $p['display_name'])[0], 'address' => $sub ?: $p['display_name'],
                'full_address' => $p['display_name'], 'lat' => (float) $p['lat'], 'lng' => (float) $p['lon']];
        }, $r['json'] ?? []);
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
