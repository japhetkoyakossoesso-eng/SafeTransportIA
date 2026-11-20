<script setup>
import { STATUTS } from '../libelles.js';

defineProps({
  simulated: { type: Boolean, default: false },
  validationStatus: { type: String, default: 'validated' },
});
</script>

<template>
  <span>
    <span v-if="simulated" class="etiquette simule" title="Donnée inventée pour les tests et la démonstration">Simulé</span>
    <span v-if="validationStatus !== 'validated'" class="etiquette non-verifie">
      {{ STATUTS[validationStatus] || validationStatus }}
    </span>
  </span>
</template>
