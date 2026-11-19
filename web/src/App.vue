<script setup>
import ServiceStatus from './components/ServiceStatus.vue';
</script>

<template>
  <main>
    <h1>SafeTransport AI</h1>
    <p>
      Squelette du front-end. Prochaines étapes : tableau de bord, carte des risques (Leaflet),
      saisie des signalements, suivi des recommandations.
    </p>
    <h2>État des services</h2>
    <ul>
      <ServiceStatus name="API (Spring Boot)" url="/api/v1/health" />
      <ServiceStatus name="IA (FastAPI)" url="/ai/health" />
    </ul>
  </main>
</template>

<style>
body { font-family: system-ui, sans-serif; margin: 2rem; color: #1d2433; }
main { max-width: 48rem; }
</style>
