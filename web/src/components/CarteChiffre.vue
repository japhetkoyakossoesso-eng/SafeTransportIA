<script setup>
import { computed } from 'vue';
import { useCompteur } from '../compteur.js';

const props = defineProps({
  libelle: { type: String, required: true },
  valeur: { type: Number, default: 0 },
  detail: { type: String, default: '' },
  icone: { type: [Object, Function], required: true },
  teinte: { type: String, default: 'marque' },
  chargement: { type: Boolean, default: false },
});

const affiche = useCompteur(computed(() => props.valeur));
</script>

<template>
  <article class="carte chiffre-cle" :style="{ '--t': `var(--${teinte})` }">
    <div class="haut">
      <span class="libelle">{{ libelle }}</span>
      <span class="pastille"><component :is="icone" :size="18" aria-hidden="true" /></span>
    </div>
    <div v-if="chargement" class="squelette valeur-attente" />
    <p v-else class="valeur chiffre">{{ affiche.toLocaleString('fr-FR') }}</p>
    <p class="discret detail">{{ detail }}</p>
  </article>
</template>

<style scoped>
.chiffre-cle { position: relative; overflow: hidden; transition: transform 0.2s, box-shadow 0.2s; }
.chiffre-cle:hover { transform: translateY(-2px); box-shadow: var(--ombre-forte); }
.chiffre-cle::after {
  content: ''; position: absolute; inset: auto -30% -60% auto; width: 9rem; height: 9rem; border-radius: 50%;
  background: radial-gradient(circle, color-mix(in srgb, var(--t) 16%, transparent), transparent 70%);
}
.haut { display: flex; justify-content: space-between; align-items: center; }
.libelle { font-size: 0.85rem; font-weight: 600; color: var(--discret); }
.pastille { display: grid; place-items: center; width: 2.2rem; height: 2.2rem; border-radius: 12px; color: var(--t); background: color-mix(in srgb, var(--t) 14%, transparent); }
.valeur { margin: 0.6rem 0 0.2rem; font-size: 2.1rem; font-weight: 800; letter-spacing: -0.02em; }
.valeur-attente { height: 2.6rem; width: 60%; margin: 0.6rem 0 0.2rem; }
.detail { margin: 0; min-height: 1.3em; }
@media (max-width: 720px) {
  .chiffre-cle { padding: 1rem; }
  .valeur { font-size: 1.6rem; }
  .pastille { width: 1.9rem; height: 1.9rem; }
}
</style>
