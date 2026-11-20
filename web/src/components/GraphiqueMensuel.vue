<script setup>
import { ImageDown } from 'lucide-vue-next';
import { computed, ref } from 'vue';
import { axe, axeCategories, bulle, degrade, telechargerImage, useGraphique } from '../graphiques.js';
import { couleur } from '../theme.js';

const props = defineProps({
  mois: { type: Array, required: true },
  sources: { type: Array, default: () => [] },
});
const toile = ref(null);

const NOMS = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
const uneSeuleAnnee = computed(() => new Set(props.mois.map((m) => m.key.slice(0, 4))).size <= 1);

function libelle(cle) {
  const [annee, mois] = cle.split('-');
  return uneSeuleAnnee.value ? NOMS[Number(mois) - 1] : `${NOMS[Number(mois) - 1]} ${annee}`;
}

const legende = computed(() => `Source : ${props.sources.length ? props.sources.join(', ') : 'aucune'}`);

const graphique = useGraphique(toile, () => ({
  type: 'line',
  data: {
    labels: props.mois.map((m) => libelle(m.key)),
    datasets: [
      {
        label: 'Accidents', data: props.mois.map((m) => m.accidents), yAxisID: 'y', fill: true, tension: 0.4,
        borderColor: couleur('marque'), backgroundColor: degrade(couleur('marque')), borderWidth: 2.5,
        pointRadius: uneSeuleAnnee.value ? 3 : 0, pointHoverRadius: 5,
      },
      {
        label: 'Tués', data: props.mois.map((m) => m.fatalities), yAxisID: 'y2', tension: 0.4,
        borderColor: couleur('fatal'), backgroundColor: couleur('fatal'), borderWidth: 2, borderDash: [5, 4],
        pointRadius: 0, pointHoverRadius: 5,
      },
    ],
  },
  options: {
    responsive: true,
    maintainAspectRatio: false,
    interaction: { mode: 'index', intersect: false },
    plugins: {
      legend: { align: 'end', labels: { color: couleur('discret'), usePointStyle: true, boxWidth: 7, boxHeight: 7 } },
      tooltip: bulle(),
    },
    scales: {
      x: { ...axeCategories(), ticks: { color: couleur('discret'), maxRotation: 0, autoSkipPadding: 14 } },
      y: axe(''),
      y2: axe('', { position: 'right', grid: { drawOnChartArea: false } }),
    },
  },
}), () => props.mois);

function exporter() {
  telechargerImage(graphique(), `${legende.value}. Nombres bruts, non rapportés à l'exposition.`, 'evolution-mensuelle.png');
}
</script>

<template>
  <section class="carte">
    <div class="entete-carte">
      <div>
        <h2>Évolution mois par mois</h2>
        <p class="discret sous-titre">Accidents et personnes tuées (pointillés, échelle de droite)</p>
      </div>
      <button class="bouton discret" title="Télécharger l'image" aria-label="Télécharger l'image" :disabled="!mois.length" @click="exporter">
        <ImageDown :size="18" aria-hidden="true" />
      </button>
    </div>
    <p v-if="!mois.length" class="discret">Aucune donnée pour cette période.</p>
    <div v-show="mois.length" class="zone">
      <canvas ref="toile" role="img" aria-label="Nombre d'accidents et de tués par mois" />
    </div>
    <p class="discret source">{{ legende }}</p>
  </section>
</template>

<style scoped>
.sous-titre { margin: 0.15rem 0 0; }
.zone { position: relative; height: 16rem; }
.source { margin: 0.75rem 0 0; font-size: 0.8rem; }
</style>
