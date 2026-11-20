import { onBeforeUnmount, ref, watch } from 'vue';

// Fait défiler un nombre jusqu'à sa valeur, en moins d'une seconde
export function useCompteur(source) {
  const affiche = ref(0);
  let image = null;
  const calme = window.matchMedia?.('(prefers-reduced-motion: reduce)').matches;

  watch(source, (cible) => {
    cancelAnimationFrame(image);
    if (calme || typeof requestAnimationFrame === 'undefined') {
      affiche.value = cible;
      return;
    }
    const depart = affiche.value;
    const debut = performance.now();
    const pas = (t) => {
      const avance = Math.min(1, (t - debut) / 900);
      affiche.value = Math.round(depart + (cible - depart) * (1 - (1 - avance) ** 3));
      if (avance < 1) image = requestAnimationFrame(pas);
    };
    image = requestAnimationFrame(pas);
  }, { immediate: true });

  onBeforeUnmount(() => cancelAnimationFrame(image));
  return affiche;
}
