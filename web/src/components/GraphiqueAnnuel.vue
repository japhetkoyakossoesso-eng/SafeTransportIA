<script setup>
import {
  BarController, BarElement, CategoryScale, Chart, Legend, LinearScale, LineController, LineElement, PointElement,
  Tooltip,
} from 'chart.js';
import { onBeforeUnmount, onMounted, ref, watch } from 'vue';

Chart.register(BarController, BarElement, CategoryScale, LinearScale, LineController, LineElement, PointElement,
  Tooltip, Legend);

const props = defineProps({ stats: { type: Object, required: true } });

const toile = ref(null);
let graphique = null;

function source() {
  return `Source : ${props.stats.sources?.length ? props.stats.sources.join(', ') : 'aucune'}`;
}

function dessiner() {
  const annees = props.stats.years || [];
  const donnees = {
    labels: annees.map((a) => String(a.year)),
    datasets: [
      { type: 'bar', label: 'Accidents', data: annees.map((a) => a.accidents), backgroundColor: '#1f5fbf', yAxisID: 'y' },
      { type: 'line', label: 'Tués', data: annees.map((a) => a.fatalities), borderColor: '#b3261e', backgroundColor: '#b3261e', yAxisID: 'y2' },
    ],
  };
  if (graphique) {
    graphique.data = donnees;
    graphique.update();
    return;
  }
  graphique = new Chart(toile.value, {
    data: donnees,
    options: {
      responsive: true,
      maintainAspectRatio: false,
      scales: {
        y: { beginAtZero: true, title: { display: true, text: 'Accidents' } },
        y2: { beginAtZero: true, position: 'right', grid: { drawOnChartArea: false }, title: { display: true, text: 'Tués' } },
      },
    },
  });
}

// L'image exportée garde la source écrite sous le graphique, sur fond blanc
function exporter() {
  const toileGraphique = graphique.canvas;
  const echelle = toileGraphique.width / toileGraphique.clientWidth || 1;
  const image = document.createElement('canvas');
  image.width = toileGraphique.width;
  image.height = toileGraphique.height + 36 * echelle;
  const ctx = image.getContext('2d');
  ctx.fillStyle = '#ffffff';
  ctx.fillRect(0, 0, image.width, image.height);
  ctx.drawImage(toileGraphique, 0, 0);
  ctx.fillStyle = '#5b6475';
  ctx.font = `${12 * echelle}px system-ui, sans-serif`;
  ctx.fillText(source(), 8 * echelle, toileGraphique.height + 24 * echelle, image.width - 16 * echelle);
  const lien = document.createElement('a');
  lien.href = image.toDataURL('image/png');
  lien.download = 'evolution-annuelle.png';
  lien.click();
}

onMounted(dessiner);
watch(() => props.stats, dessiner);
onBeforeUnmount(() => graphique?.destroy());
</script>

<template>
  <section class="carte">
    <div class="titre-graphique">
      <h2>Évolution annuelle</h2>
      <button class="secondaire" :disabled="!stats.years?.length" @click="exporter">Télécharger l'image</button>
    </div>
    <p v-if="!stats.years?.length" class="discret">Aucune donnée pour ces filtres.</p>
    <div v-show="stats.years?.length" class="zone"><canvas ref="toile" /></div>
    <p class="discret source">
      {{ source() }}. Nombres bruts, non rapportés à l'exposition.
    </p>
  </section>
</template>

<style scoped>
.titre-graphique { display: flex; justify-content: space-between; align-items: center; gap: 1rem; }
h2 { font-size: 1.1rem; margin: 0; }
.zone { position: relative; height: 16rem; }
</style>
