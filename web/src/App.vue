<script setup>
import { computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { deconnexion, lireJeton } from './api.js';
import ServiceStatus from './components/ServiceStatus.vue';

const route = useRoute();
const router = useRouter();
const connecte = computed(() => route.name && route.name !== 'connexion' && !!lireJeton());

function utilisateur() {
  try {
    return JSON.parse(localStorage.getItem('safetransport.utilisateur') || '{}').username || '';
  } catch {
    return '';
  }
}

function quitter() {
  deconnexion();
  router.push({ name: 'connexion' });
}
</script>

<template>
  <header class="entete">
    <div class="page barre">
      <router-link to="/" class="titre">SafeTransport AI</router-link>
      <span v-if="connecte" class="compte">
        {{ utilisateur() }}
        <button class="secondaire" @click="quitter">Se déconnecter</button>
      </span>
    </div>
  </header>
  <router-view />
  <footer class="page discret">
    <p>
      Aide à l'analyse : les chiffres viennent de sources publiques citées sur chaque page. Les données simulées
      ou non vérifiées sont étiquetées.
    </p>
    <ul class="services">
      <ServiceStatus name="API" url="/api/v1/health" />
      <ServiceStatus name="IA" url="/ai/health" />
    </ul>
  </footer>
</template>

<style>
.entete { background: var(--carte); border-bottom: 1px solid var(--bord); }
.barre { display: flex; justify-content: space-between; align-items: center; gap: 1rem; padding-top: 0.6rem; padding-bottom: 0.6rem; }
.titre { font-weight: 700; font-size: 1.15rem; text-decoration: none; color: var(--texte); }
.compte { display: flex; align-items: center; gap: 0.5rem; font-size: 0.9rem; }
.services { display: flex; gap: 1.5rem; padding: 0; list-style: none; }
</style>
