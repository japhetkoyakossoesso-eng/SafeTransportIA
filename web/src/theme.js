import { ref } from 'vue';

const CLE = 'safetransport.theme';

function choixEnregistre() {
  try {
    return localStorage.getItem(CLE);
  } catch {
    return null;
  }
}

function themeSysteme() {
  return window.matchMedia?.('(prefers-color-scheme: dark)').matches ? 'sombre' : 'clair';
}

export const theme = ref(choixEnregistre() || themeSysteme());

function appliquer() {
  document.documentElement.dataset.theme = theme.value;
}

export function basculerTheme() {
  theme.value = theme.value === 'sombre' ? 'clair' : 'sombre';
  try {
    localStorage.setItem(CLE, theme.value);
  } catch {
    // tant pis, le choix ne durera que pour cette page
  }
  appliquer();
}

// Sans choix enregistré, on suit le réglage du système
window.matchMedia?.('(prefers-color-scheme: dark)').addEventListener?.('change', () => {
  if (!choixEnregistre()) {
    theme.value = themeSysteme();
    appliquer();
  }
});

appliquer();

// Les graphiques lisent les couleurs du thème courant
export function couleur(nom) {
  return getComputedStyle(document.documentElement).getPropertyValue(`--${nom}`).trim() || '#888';
}
