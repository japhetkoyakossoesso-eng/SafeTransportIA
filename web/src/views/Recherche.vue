<script setup>
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { NonConnecte, lire, telechargerCsv } from '../api.js';
import Filtres from '../components/Filtres.vue';
import GraphiqueAnnuel from '../components/GraphiqueAnnuel.vue';
import ListeAccidents from '../components/ListeAccidents.vue';
import { depuisQuery, versQuery } from '../filtres.js';

const TAILLE = 50;
const route = useRoute();
const router = useRouter();

const filtres = computed(() => depuisQuery(route.query));
const page = computed(() => Number(route.query.page || 0));
const resultat = ref({ items: [], total: 0 });
const stats = ref({ years: [], sources: [] });
const chargement = ref(false);
const erreur = ref('');

const pages = computed(() => Math.max(1, Math.ceil(resultat.value.total / TAILLE)));

async function charger() {
  chargement.value = true;
  erreur.value = '';
  try {
    const [liste, annuel] = await Promise.all([
      lire('/api/v1/accidents', { ...filtres.value, page: page.value, size: TAILLE }),
      lire('/api/v1/accidents/stats/annual', filtres.value),
    ]);
    resultat.value = liste;
    stats.value = annuel;
  } catch (e) {
    if (e instanceof NonConnecte) {
      router.push({ name: 'connexion', query: { retour: route.fullPath } });
      return;
    }
    erreur.value = e.message;
  } finally {
    chargement.value = false;
  }
}

function changerFiltres(nouveaux) {
  router.push({ query: versQuery(nouveaux) });
}

function allerPage(n) {
  router.push({ query: versQuery(filtres.value, n) });
}

async function exporter() {
  try {
    await telechargerCsv(filtres.value);
  } catch (e) {
    erreur.value = e.message;
  }
}

watch(() => route.query, charger, { immediate: true });
</script>

<template>
  <main class="page">
    <Filtres :model-value="filtres" @update:model-value="changerFiltres" />
    <p v-if="erreur" class="erreur">{{ erreur }}</p>
    <p v-if="!filtres.includeUnverified" class="discret">
      Seuls les accidents validés sont affichés. Cochez « non vérifiés » pour voir aussi les imports pas encore revus.
    </p>
    <GraphiqueAnnuel :stats="stats" />
    <section class="carte">
      <div class="entete-liste">
        <h2>{{ resultat.total.toLocaleString('fr-FR') }} accident(s)</h2>
        <button class="secondaire" :disabled="!resultat.total" @click="exporter">Exporter en CSV</button>
      </div>
      <p v-if="chargement" class="discret">Chargement…</p>
      <ListeAccidents v-else :accidents="resultat.items" />
      <nav v-if="pages > 1" class="pagination">
        <button class="secondaire" :disabled="page === 0" @click="allerPage(page - 1)">Précédent</button>
        <span>Page {{ page + 1 }} sur {{ pages }}</span>
        <button class="secondaire" :disabled="page + 1 >= pages" @click="allerPage(page + 1)">Suivant</button>
      </nav>
    </section>
  </main>
</template>

<style scoped>
.entete-liste { display: flex; justify-content: space-between; align-items: center; gap: 1rem; }
h2 { font-size: 1.1rem; margin: 0 0 0.5rem; }
.pagination { display: flex; justify-content: center; align-items: center; gap: 1rem; margin-top: 1rem; }
</style>
