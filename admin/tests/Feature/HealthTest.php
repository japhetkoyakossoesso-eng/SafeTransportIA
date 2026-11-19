<?php

namespace Tests\Feature;

use Tests\TestCase;

class HealthTest extends TestCase
{
    public function test_health_endpoint_answers(): void
    {
        $this->getJson('/health')
            ->assertOk()
            ->assertJsonPath('service', 'admin');
    }
}
