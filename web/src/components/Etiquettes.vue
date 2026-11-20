<script setup>
import { FlaskConical, ShieldAlert } from 'lucide-vue-next';
import { STATUTS } from '../libelles.js';

defineProps({
  simulated: { type: Boolean, default: false },
  validationStatus: { type: String, default: 'validated' },
});
</script>

<template>
  <span class="etiquettes">
    <span v-if="simulated" class="etiquette simule" title="Donnée inventée pour les tests et la démonstration">
      <FlaskConical :size="12" aria-hidden="true" />Simulé
    </span>
    <span v-if="validationStatus !== 'validated'" class="etiquette non-verifie" title="Pas encore validé par un responsable">
      <ShieldAlert :size="12" aria-hidden="true" />{{ STATUTS[validationStatus] || validationStatus }}
    </span>
  </span>
</template>

<style scoped>
.etiquettes { display: inline-flex; flex-wrap: wrap; gap: 0.25rem; }
.etiquette { margin: 0; }
</style>
