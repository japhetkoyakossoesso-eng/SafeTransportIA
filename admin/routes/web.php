<?php

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

Route::get('/health', function () {
    try {
        DB::select('select 1');
        return ['service' => 'admin', 'status' => 'ok', 'database' => 'ok'];
    } catch (Throwable $e) {
        return ['service' => 'admin', 'status' => 'degraded', 'database' => 'indisponible'];
    }
});
