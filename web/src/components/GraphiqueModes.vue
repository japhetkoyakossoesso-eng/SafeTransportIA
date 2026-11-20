<script setup>
import { computed, ref } from 'vue';
import { bulle, useGraphique } from '../graphiques.js';
import { MODES } from '../libelles.js';
import { couleur } from '../theme.js';
import IconeMode from './IconeMode.vue';

const props = defineProps({ modes: { type: Array, required: true } });
const toile = ref(null);
const total = computed(() => props.modes.reduce((s, m) => s + m.accidents, 0));

function part(n) {
  return total.value ? `${((100 * n) / total.value).toLocaleString('fr-FR', { maximumFractionDigits: 1 })} %` : '';
}

useGraphique(toile, () => ({
  type: 'doughnut',
  data: {
    labels: props.modes.map((m) => MODES[m.key] || m.key),
    datasets: [{
      data: props.modes.map((m) => m.accidents),
      backgroundColor: props.modes.map((m) => couleur(m.key)),
      borderColor: couleur('surface'),
      borderWidth: 3,
      hoverOffset: 6,
    }],
  },
  options: {
    responsive: true,
    maintainAspectRatio: false,
    cutout: '72%',
    plugins: { legend: { display: false }, tooltip: bulle() },
  },
}), () => props.modes);
</script>

<template>
  <section class="carte">
    <h2>Répartition par mode</h2>
    <p class="discret sous-titre">Part des accidents de la période</p>
    <p v-if="!modes.length" class="discret">Aucune donnée.</p>
    <div v-show="modes.length" class="anneau">
      <canvas ref="toile" role="img" aria-label="Répartition des accidents par mode de transport" />
      <div class="centre"><strong class="chiffre">{{ total.toLocaleString('fr-FR') }}</strong><span>accidents</span></div>
    </div>
    <ul class="legende">
      <li v-for="m in modes" :key="m.key">
        <IconeMode :mode="m.key" :taille="15" />
        <span class="nom">{{ MODES[m.key] || m.key }}</span>
        <span class="chiffre">{{ m.accidents.toLocaleString('fr-FR') }}</span>
        <span class="discret part">{{ part(m.accidents) }}</span>
      </li>
    </ul>
  </section>
</template>

<style scoped>
.sous-titre { margin: 0.15rem 0 0.75rem; }
.anneau { position: relative; height: 11.5rem; }
.centre { position: absolute; inset: 0; display: grid; place-content: center; text-align: center; pointer-events: none; }
.centre strong { font-size: 1.5rem; font-weight: 800; }
.centre span { font-size: 0.78rem; color: var(--discret); }
.legende { list-style: none; padding: 0; margin: 1rem 0 0; display: grid; gap: 0.5rem; }
.legende li { display: grid; grid-template-columns: auto 1fr auto 3.5rem; align-items: center; gap: 0.6rem; font-size: 0.9rem; }
.nom { font-weight: 600; }
.part { text-align: right; }
</style>
