import {
  ArcElement, BarController, BarElement, CategoryScale, Chart, DoughnutController, Filler, Legend, LinearScale,
  LineController, LineElement, PointElement, Tooltip,
} from 'chart.js';
import { onBeforeUnmount, onMounted, watch } from 'vue';
import { couleur, theme } from './theme.js';

Chart.register(ArcElement, BarController, BarElement, CategoryScale, DoughnutController, Filler, Legend, LinearScale,
  LineController, LineElement, PointElement, Tooltip);

export function transparence(hex, alpha) {
  const n = parseInt(hex.replace('#', ''), 16);
  if (Number.isNaN(n)) return hex;
  return `rgba(${(n >> 16) & 255}, ${(n >> 8) & 255}, ${n & 255}, ${alpha})`;
}

// Dégradé vertical sous une courbe
export function degrade(teinte) {
  return ({ chart }) => {
    const { ctx, chartArea } = chart;
    if (!chartArea) return transparence(teinte, 0.2);
    const g = ctx.createLinearGradient(0, chartArea.top, 0, chartArea.bottom);
    g.addColorStop(0, transparence(teinte, 0.35));
    g.addColorStop(1, transparence(teinte, 0));
    return g;
  };
}

export function bulle() {
  return {
    backgroundColor: couleur('surface'),
    titleColor: couleur('texte'),
    bodyColor: couleur('texte'),
    borderColor: couleur('bord'),
    borderWidth: 1,
    padding: 10,
    cornerRadius: 10,
    boxPadding: 4,
    usePointStyle: true,
    callbacks: { label: (c) => ` ${c.dataset.label ? `${c.dataset.label} : ` : ''}${Number(c.raw).toLocaleString('fr-FR')}` },
  };
}

export function axe(titre, autres = {}) {
  return {
    beginAtZero: true,
    border: { display: false },
    grid: { color: couleur('bord') },
    ticks: { color: couleur('discret'), callback: (v) => Number(v).toLocaleString('fr-FR') },
    title: { display: !!titre, text: titre, color: couleur('discret') },
    ...autres,
  };
}

export function axeCategories() {
  return { grid: { display: false }, border: { display: false }, ticks: { color: couleur('discret') } };
}

// Crée le graphique, le met à jour quand les données ou le thème changent
export function useGraphique(toile, construire, source) {
  let graphique = null;

  function dessiner() {
    if (!toile.value) return;
    const config = construire();
    if (!graphique) {
      graphique = new Chart(toile.value, config);
      return;
    }
    graphique.data = config.data;
    graphique.options = config.options;
    graphique.update();
  }

  onMounted(dessiner);
  watch([source, theme], dessiner, { deep: true });
  onBeforeUnmount(() => graphique?.destroy());
  return () => graphique;
}

// L'image téléchargée garde la source écrite sous le graphique
export function telechargerImage(graphique, legende, nom) {
  const toile = graphique.canvas;
  const echelle = toile.width / toile.clientWidth || 1;
  const image = document.createElement('canvas');
  image.width = toile.width;
  image.height = toile.height + 36 * echelle;
  const ctx = image.getContext('2d');
  ctx.fillStyle = couleur('surface');
  ctx.fillRect(0, 0, image.width, image.height);
  ctx.drawImage(toile, 0, 0);
  ctx.fillStyle = couleur('discret');
  ctx.font = `${12 * echelle}px system-ui, sans-serif`;
  ctx.fillText(legende, 8 * echelle, toile.height + 24 * echelle, image.width - 16 * echelle);
  const lien = document.createElement('a');
  lien.href = image.toDataURL('image/png');
  lien.download = nom;
  lien.click();
}
