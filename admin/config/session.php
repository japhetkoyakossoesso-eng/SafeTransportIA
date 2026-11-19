<?php

use Illuminate\Support\Str;

return [
    // Stockage des sessions
    'driver' => env('SESSION_DRIVER', 'database'),

    // Durée de vie des sessions
    'lifetime' => (int) env('SESSION_LIFETIME', 120),

    'expire_on_close' => env('SESSION_EXPIRE_ON_CLOSE', false),

    // Chiffrement des sessions
    'encrypt' => env('SESSION_ENCRYPT', false),

    // Dossier des sessions
    'files' => storage_path('framework/sessions'),

    // Connexion pour les sessions
    'connection' => env('SESSION_CONNECTION'),

    // Table des sessions
    'table' => env('SESSION_TABLE', 'sessions'),

    // Cache des sessions
    'store' => env('SESSION_STORE'),

    // Nettoyage des vieilles sessions
    'lottery' => [2, 100],

    // Nom du cookie de session
    'cookie' => env(
        'SESSION_COOKIE',
        Str::slug((string) env('APP_NAME', 'laravel')).'-session'
    ),

    // Chemin du cookie
    'path' => env('SESSION_PATH', '/'),

    // Domaine du cookie
    'domain' => env('SESSION_DOMAIN'),

    // Cookies en HTTPS uniquement
    'secure' => env('SESSION_SECURE_COOKIE'),

    // Cookie inaccessible au JavaScript
    'http_only' => env('SESSION_HTTP_ONLY', true),

    // Cookies same-site
    'same_site' => env('SESSION_SAME_SITE', 'lax'),

    // Cookies partitionnés
    'partitioned' => env('SESSION_PARTITIONED_COOKIE', false),

    // Sérialisation des sessions
    'serialization' => 'json',
];
