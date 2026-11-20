<script setup>
import { ImageDown } from 'lucide-vue-next';
import { ref } from 'vue';
import { axe, axeCategories, bulle, telechargerImage, useGraphique } from '../graphiques.js';
import { couleur } from '../theme.js';

const props = defineProps({ stats: { type: Object, required: true } });
const toile = ref(null);

function source() {
  return `Source : ${props.stats.sources?.length ? props.stats.sources.join(', ') : 'aucune'}`;
}

const graphique = useGraphique(toile, () => {
  const annees = props.stats.years || [];
  return {
    data: {
      labels: annees.map((a) => String(a.year)),
      datasets: [
        {
          type: 'bar', label: 'Accidents', data: annees.map((a) => a.accidents), yAxisID: 'y',
          backgroundColor: couleur('marque'), borderRadius: 6, maxBarThickness: 46,
        },
        {
          type: 'line', label: 'Tués', data: annees.map((a) => a.fatalities), yAxisID: 'y2', tension: 0.35,
          borderColor: couleur('fatal'), backgroundColor: couleur('fatal'), pointRadius: 4, borderWidth: 2.5,
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
        x: axeCategories(),
        y: axe('Accidents'),
        y2: axe('Tués', { position: 'right', grid: { drawOnChartArea: false } }),
      },
    },
  };
}, () => props.stats);

function exporter() {
  telechargerImage(graphique(), `${source()}. Nombres bruts, non rapportés à l'exposition.`, 'evolution-annuelle.png');
}
</script>

<template>
  <section class="carte">
    <div class="entete-carte">
      <div>
        <h2>Évolution annuelle</h2>
        <p class="discret sous-titre">Accidents (barres) et personnes tuées (courbe)</p>
      </div>
      <button class="bouton secondaire" :disabled="!stats.years?.length" @click="exporter">
        <ImageDown :size="16" aria-hidden="true" />Télécharger l'image
      </button>
    </div>
    <p v-if="!stats.years?.length" class="discret">Aucune donnée pour ces filtres.</p>
    <div v-show="stats.years?.length" class="zone">
      <canvas ref="toile" role="img" aria-label="Nombre d'accidents et de tués par année" />
    </div>
    <p class="discret source">{{ source() }}. Nombres bruts, non rapportés à l'exposition.</p>
  </section>
</template>

<style scoped>
.sous-titre, .source { margin: 0.15rem 0 0; }
.zone { position: relative; height: 17rem; }
.source { margin-top: 0.75rem; font-size: 0.8rem; }
</style>
