<script setup>
import { Car, CircleHelp, Plane, Ship, TrainFront } from 'lucide-vue-next';
import { MODES } from '../libelles.js';

defineProps({ mode: { type: String, required: true }, taille: { type: Number, default: 18 } });
const ICONES = { road: Car, air: Plane, rail: TrainFront, maritime: Ship };
</script>

<template>
  <span class="icone-mode" :class="`mode-${mode}`" :title="MODES[mode] || mode">
    <component :is="ICONES[mode] || CircleHelp" :size="taille" aria-hidden="true" />
  </span>
</template>

<style scoped>
.icone-mode {
  display: inline-grid; place-items: center; flex: none; width: 2em; height: 2em; border-radius: 10px;
  color: var(--m, var(--discret)); background: color-mix(in srgb, var(--m, var(--discret)) 14%, transparent);
}
</style>
