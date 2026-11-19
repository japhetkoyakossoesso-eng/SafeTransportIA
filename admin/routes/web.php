<?php

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;

// Back-office SafeTransport AI (stub). À venir : gestion des référentiels, des comptes
// et de leurs rôles, file de validation des signalements, suivi des recommandations.
Route::get('/', function () {
    return view('welcome');
});

Route::get('/health', function () {
    try {
        DB::select('select 1');
        $database = DB::connection()->getDriverName().' : ok';
        $status = 'ok';
    } catch (Throwable $e) {
        $database = 'indisponible : '.class_basename($e);
        $status = 'degraded';
    }

    return response()->json(['service' => 'admin', 'status' => $status, 'database' => $database]);
});
