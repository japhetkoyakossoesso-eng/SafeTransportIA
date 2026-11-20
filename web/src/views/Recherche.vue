<script setup>
import { ChevronLeft, ChevronRight, CircleAlert, Download, Info, SlidersHorizontal } from 'lucide-vue-next';
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { NonConnecte, lire, telechargerCsv } from '../api.js';
import Filtres from '../components/Filtres.vue';
import GraphiqueAnnuel from '../components/GraphiqueAnnuel.vue';
import ListeAccidents from '../components/ListeAccidents.vue';
import { depuisQuery, versQuery } from '../filtres.js';
import { GRAVITES, MODES, date } from '../libelles.js';

const TAILLE = 50;
const route = useRoute();
const router = useRouter();

const filtres = computed(() => depuisQuery(route.query));
const page = computed(() => Number(route.query.page || 0));
const resultat = ref({ items: [], total: 0 });
const stats = ref({ years: [], sources: [] });
const chargement = ref(false);
const erreur = ref('');
const panneau = ref(false);

const pages = computed(() => Math.max(1, Math.ceil(resultat.value.total / TAILLE)));

// Résumé lisible des filtres actifs, affiché au-dessus des résultats
const actifs = computed(() => {
  const f = filtres.value;
  const liste = [];
  if (f.mode) liste.push(MODES[f.mode]);
  if (f.from || f.to) liste.push(`${f.from ? date(f.from) : '…'} → ${f.to ? date(f.to) : '…'}`);
  if (f.country) liste.push(f.country === 'FR' ? 'France' : f.country === 'US' ? 'États-Unis' : f.country);
  if (f.source) liste.push(f.source);
  f.severity.forEach((g) => liste.push(GRAVITES[g]));
  if (f.includeUnverified) liste.push('+ non vérifiés');
  if (f.includeSimulated) liste.push('+ simulés');
  return liste;
});

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
  panneau.value = false;
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
  <main class="page recherche">
    <header class="titre-page apparition">
      <div>
        <h1>Recherche</h1>
        <p class="discret">Filtrez les accidents, ouvrez une fiche ou exportez le résultat.</p>
      </div>
      <button class="bouton secondaire ouvrir-filtres" :aria-expanded="panneau" @click="panneau = !panneau">
        <SlidersHorizontal :size="16" aria-hidden="true" />Filtres<span v-if="actifs.length" class="compte">{{ actifs.length }}</span>
      </button>
    </header>

    <div class="disposition">
      <aside class="cote" :class="{ ouvert: panneau }">
        <Filtres :model-value="filtres" @update:model-value="changerFiltres" />
      </aside>

      <div class="resultats">
        <p v-if="erreur" class="erreur"><CircleAlert :size="17" aria-hidden="true" />{{ erreur }}</p>
        <p v-if="!filtres.includeUnverified" class="info">
          <Info :size="16" aria-hidden="true" />
          Seuls les accidents validés sont affichés. Activez « non vérifiés » pour voir aussi les imports pas encore revus.
        </p>

        <GraphiqueAnnuel :stats="stats" class="apparition" />

        <section class="carte apparition">
          <div class="entete-carte">
            <div>
              <h2><span class="chiffre total">{{ resultat.total.toLocaleString('fr-FR') }}</span> accident(s)</h2>
              <ul v-if="actifs.length" class="actifs">
                <li v-for="a in actifs" :key="a">{{ a }}</li>
              </ul>
            </div>
            <button class="bouton secondaire" :disabled="!resultat.total" @click="exporter">
              <Download :size="16" aria-hidden="true" />Exporter en CSV
            </button>
          </div>
          <div v-if="chargement" class="attente" aria-label="Chargement">
            <div v-for="i in 6" :key="i" class="squelette" />
          </div>
          <p v-else-if="!resultat.items.length" class="vide discret">Aucun accident ne correspond à ces filtres.</p>
          <ListeAccidents v-else :accidents="resultat.items" />
          <nav v-if="pages > 1" class="pagination" aria-label="Pages">
            <button class="bouton secondaire" :disabled="page === 0" @click="allerPage(page - 1)">
              <ChevronLeft :size="16" aria-hidden="true" />Précédent
            </button>
            <span class="discret">Page <strong>{{ page + 1 }}</strong> sur {{ pages.toLocaleString('fr-FR') }}</span>
            <button class="bouton secondaire" :disabled="page + 1 >= pages" @click="allerPage(page + 1)">
              Suivant<ChevronRight :size="16" aria-hidden="true" />
            </button>
          </nav>
        </section>
      </div>
    </div>
  </main>
</template>

<style scoped>
.titre-page { display: flex; justify-content: space-between; align-items: flex-end; gap: 1rem; margin-bottom: 1.25rem; }
.titre-page h1 { margin: 0; font-size: 1.8rem; font-weight: 800; }
.titre-page p { margin: 0.2rem 0 0; }
.ouvrir-filtres { display: none; }
.compte { background: var(--marque); color: #fff; border-radius: 999px; font-size: 0.72rem; padding: 0 0.4rem; }
.disposition { display: grid; grid-template-columns: 19rem 1fr; gap: 1.25rem; align-items: start; }
.cote { position: sticky; top: 4.75rem; }
.resultats { display: grid; gap: 1rem; min-width: 0; }
.info { display: flex; gap: 0.5rem; align-items: center; margin: 0; font-size: 0.85rem; color: var(--discret); }
.info svg { flex: none; color: var(--marque); }
.total { font-size: 1.5rem; font-weight: 800; color: var(--marque); }
.actifs { list-style: none; display: flex; flex-wrap: wrap; gap: 0.3rem; padding: 0; margin: 0.4rem 0 0; }
.actifs li { font-size: 0.75rem; padding: 0.1rem 0.5rem; border-radius: 999px; background: var(--marque-doux); color: var(--marque); font-weight: 600; }
.attente { display: grid; gap: 0.5rem; }
.attente .squelette { height: 2.6rem; }
.vide { text-align: center; padding: 2rem 0; }
.pagination { display: flex; justify-content: center; align-items: center; gap: 1rem; margin-top: 1.25rem; flex-wrap: wrap; }

@media (max-width: 1000px) {
  .disposition { grid-template-columns: 1fr; }
  .ouvrir-filtres { display: inline-flex; }
  .cote { position: static; display: none; }
  .cote.ouvert { display: block; animation: monte 0.25s both; }
}
</style>
