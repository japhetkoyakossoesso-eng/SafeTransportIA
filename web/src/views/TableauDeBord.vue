<script setup>
import { Activity, ArrowRight, BadgeCheck, CircleAlert, HeartPulse, Info, Skull } from 'lucide-vue-next';
import { computed, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { NonConnecte, lire, lireUtilisateur } from '../api.js';
import CarteChiffre from '../components/CarteChiffre.vue';
import GraphiqueMensuel from '../components/GraphiqueMensuel.vue';
import GraphiqueModes from '../components/GraphiqueModes.vue';
import IconeMode from '../components/IconeMode.vue';
import { GRAVITES, MODES, date, lieuCourt } from '../libelles.js';

const route = useRoute();
const router = useRouter();
const VIDE = { totals: { accidents: 0, fatalAccidents: 0, fatalities: 0, seriousInjuries: 0 }, modes: [], severities: [], months: [], sources: [] };

const annees = ref([]);
const apercu = ref(VIDE);
const mortels = ref([]);
const chargement = ref(true);
const erreur = ref('');

const annee = computed(() => route.query.annee || (annees.value.length ? String(annees.value.at(-1)) : ''));
const mode = computed(() => route.query.mode || '');
const filtres = computed(() => ({
  mode: mode.value,
  from: annee.value && annee.value !== 'toutes' ? `${annee.value}-01-01` : '',
  to: annee.value && annee.value !== 'toutes' ? `${annee.value}-12-31` : '',
}));

const periode = computed(() => {
  if (annee.value && annee.value !== 'toutes') return `Année ${annee.value}`;
  return annees.value.length ? `De ${annees.value[0]} à ${annees.value.at(-1)}` : 'Toutes les années';
});

const t = computed(() => apercu.value.totals);
function pourcent(n, sur) {
  return sur ? (100 * n / sur).toLocaleString('fr-FR', { maximumFractionDigits: 1 }) : '0';
}

const gravites = computed(() => {
  const ordre = ['fatal', 'serious', 'minor', 'none', 'unknown'];
  return [...apercu.value.severities].sort((a, b) => ordre.indexOf(a.key) - ordre.indexOf(b.key));
});

const versRecherche = computed(() => ({ name: 'recherche', query: Object.fromEntries(Object.entries(filtres.value).filter(([, v]) => v)) }));

function bonjour() {
  const h = new Date().getHours();
  return h < 18 ? 'Bonjour' : 'Bonsoir';
}

function choisir(cle, valeur) {
  const q = { ...route.query, [cle]: valeur };
  if (!valeur) delete q[cle];
  router.push({ query: q });
}

async function charger() {
  chargement.value = true;
  erreur.value = '';
  try {
    if (!annees.value.length) {
      annees.value = (await lire('/api/v1/accidents/stats/annual')).years.map((a) => a.year);
    }
    const [resume, liste] = await Promise.all([
      lire('/api/v1/accidents/stats/overview', filtres.value),
      lire('/api/v1/accidents', { ...filtres.value, severity: ['fatal'], size: 5 }),
    ]);
    apercu.value = resume;
    mortels.value = liste.items;
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

watch(() => route.query, charger, { immediate: true });
</script>

<template>
  <main class="page tableau">
    <section class="bandeau apparition">
      <div class="texte-bandeau">
        <p class="sur-titre">{{ bonjour() }}, {{ lireUtilisateur().username }}</p>
        <h1>Tableau de bord</h1>
        <p class="sous-titre">{{ periode }} · {{ mode ? MODES[mode] : 'tous les modes' }}</p>
      </div>
      <div class="reglages">
        <label class="annee">
          <span class="invisible">Année</span>
          <select :value="annee" name="annee" @change="choisir('annee', $event.target.value)">
            <option v-for="a in [...annees].reverse()" :key="a" :value="String(a)">{{ a }}</option>
            <option value="toutes">Toutes les années</option>
          </select>
        </label>
        <div class="modes" role="group" aria-label="Mode de transport">
          <button type="button" :class="{ actif: !mode }" :aria-pressed="!mode" @click="choisir('mode', '')">Tous</button>
          <button v-for="(libelle, code) in MODES" :key="code" type="button" :class="{ actif: mode === code }"
                  :aria-pressed="mode === code" @click="choisir('mode', code)">{{ libelle }}</button>
        </div>
      </div>
    </section>

    <p v-if="erreur" class="erreur"><CircleAlert :size="17" aria-hidden="true" />{{ erreur }}</p>

    <p class="perimetre">
      <BadgeCheck :size="16" aria-hidden="true" />
      Accidents validés uniquement. Les données simulées et non vérifiées ne sont pas comptées ici.
    </p>

    <section class="chiffres">
      <CarteChiffre class="apparition" libelle="Accidents" :valeur="t.accidents" :icone="Activity" teinte="marque"
                    :chargement="chargement" :detail="`${apercu.modes.length} mode(s) de transport`" />
      <CarteChiffre class="apparition" style="animation-delay: 60ms" libelle="Accidents mortels" :valeur="t.fatalAccidents"
                    :icone="CircleAlert" teinte="serious" :chargement="chargement"
                    :detail="`${pourcent(t.fatalAccidents, t.accidents)} % des accidents`" />
      <CarteChiffre class="apparition" style="animation-delay: 120ms" libelle="Personnes tuées" :valeur="t.fatalities"
                    :icone="Skull" teinte="fatal" :chargement="chargement"
                    :detail="`${pourcent(t.fatalities, t.accidents)} tués pour 100 accidents`" />
      <CarteChiffre class="apparition" style="animation-delay: 180ms" libelle="Blessés graves" :valeur="t.seriousInjuries"
                    :icone="HeartPulse" teinte="minor" :chargement="chargement" detail="selon la définition de chaque source" />
    </section>

    <section class="grille a">
      <GraphiqueMensuel class="apparition" :mois="apercu.months" :sources="apercu.sources" />
      <GraphiqueModes class="apparition" :modes="apercu.modes" />
    </section>

    <section class="grille b">
      <section class="carte apparition">
        <h2>Gravité</h2>
        <p class="discret sous-titre-carte">Gravité harmonisée entre les sources</p>
        <ul class="barres">
          <li v-for="g in gravites" :key="g.key">
            <div class="ligne-barre">
              <span :class="`gravite gravite-${g.key}`">{{ GRAVITES[g.key] || g.key }}</span>
              <span class="chiffre">{{ g.accidents.toLocaleString('fr-FR') }}
                <span class="discret">· {{ pourcent(g.accidents, t.accidents) }} %</span></span>
            </div>
            <div class="piste"><div class="remplissage" :class="`gravite-${g.key}`" :style="{ width: `${pourcent(g.accidents, t.accidents).replace(',', '.')}%` }" /></div>
          </li>
        </ul>
        <p v-if="!gravites.length && !chargement" class="discret">Aucune donnée.</p>
      </section>

      <section class="carte apparition">
        <div class="entete-carte">
          <div>
            <h2>Derniers accidents mortels</h2>
            <p class="discret sous-titre-carte">Les plus récents de la période</p>
          </div>
          <router-link :to="versRecherche" class="bouton secondaire">Tout voir<ArrowRight :size="16" aria-hidden="true" /></router-link>
        </div>
        <div v-if="chargement" class="attente"><div v-for="i in 4" :key="i" class="squelette" /></div>
        <p v-else-if="!mortels.length" class="discret">Aucun accident mortel pour ces filtres.</p>
        <ul v-else class="mortels">
          <li v-for="a in mortels" :key="a.id">
            <router-link :to="`/accidents/${a.id}`" class="mortel">
              <IconeMode :mode="a.mode" />
              <span class="quoi">
                <strong>{{ lieuCourt(a) || 'Lieu inconnu' }}</strong>
                <span class="discret">{{ date(a.date) }} · {{ MODES[a.mode] }} · {{ a.source }}</span>
              </span>
              <span class="tues"><strong class="chiffre">{{ a.fatalities ?? '?' }}</strong> tué(s)</span>
            </router-link>
          </li>
        </ul>
      </section>
    </section>

    <aside class="carte avertissement apparition">
      <Info :size="20" aria-hidden="true" />
      <p>
        Ce sont des <strong>nombres bruts</strong>. Ils ne disent pas quel mode est le plus dangereux : il faudrait les
        rapporter au trafic (kilomètres parcourus, heures de vol). Sources : {{ apercu.sources.join(', ') || 'aucune' }}.
      </p>
    </aside>
  </main>
</template>

<style scoped>
.tableau { display: grid; gap: 1.25rem; }
.bandeau {
  position: relative; overflow: hidden; border-radius: calc(var(--rayon) + 6px); padding: 1.75rem 2rem; color: #fff;
  background: var(--degrade); display: flex; justify-content: space-between; align-items: flex-end; gap: 1.5rem; flex-wrap: wrap;
  box-shadow: var(--ombre-forte);
}
.bandeau::after {
  content: ''; position: absolute; right: -4rem; top: -6rem; width: 22rem; height: 22rem; border-radius: 50%;
  background: radial-gradient(circle, rgb(255 255 255 / 18%), transparent 65%); pointer-events: none;
}
.sur-titre { margin: 0; opacity: 0.85; font-weight: 500; }
h1 { margin: 0.2rem 0; font-size: clamp(1.6rem, 3vw, 2.2rem); font-weight: 800; }
.sous-titre { margin: 0; opacity: 0.85; }
.reglages { position: relative; z-index: 1; display: flex; gap: 0.75rem; flex-wrap: wrap; align-items: center; }
.annee select { background: rgb(255 255 255 / 14%); border-color: rgb(255 255 255 / 30%); color: #fff; font-weight: 600; min-width: 11rem; }
.annee option { color: #0f172a; }
.modes { display: flex; padding: 0.25rem; border-radius: 12px; background: rgb(0 0 0 / 18%); gap: 0.15rem; flex-wrap: wrap; }
.modes button { border: 0; background: none; color: rgb(255 255 255 / 85%); padding: 0.4rem 0.8rem; border-radius: 9px; cursor: pointer; font-weight: 600; font-size: 0.88rem; transition: background-color 0.15s, color 0.15s; }
.modes button:hover { color: #fff; background: rgb(255 255 255 / 10%); }
.modes button.actif { background: #fff; color: #1e2a78; }

.perimetre { display: flex; align-items: center; gap: 0.45rem; margin: -0.25rem 0 0; font-size: 0.85rem; color: var(--succes); }
.chiffres { display: grid; grid-template-columns: repeat(4, 1fr); gap: 1rem; }
.grille { display: grid; gap: 1rem; }
.grille > * { min-width: 0; }
.grille.a { grid-template-columns: 2fr 1fr; }
.grille.b { grid-template-columns: 1fr 1.6fr; }
.sous-titre-carte { margin: 0.15rem 0 1rem; }

.barres { list-style: none; padding: 0; margin: 0; display: grid; gap: 0.9rem; }
.ligne-barre { display: flex; justify-content: space-between; align-items: center; margin-bottom: 0.35rem; font-size: 0.9rem; }
.piste { height: 0.5rem; border-radius: 999px; background: var(--surface-2); overflow: hidden; }
.remplissage { height: 100%; border-radius: 999px; background: var(--g); transition: width 0.8s cubic-bezier(0.2, 0.7, 0.2, 1); }

.attente { display: grid; gap: 0.6rem; }
.attente .squelette { height: 3.2rem; }
.mortels { list-style: none; padding: 0; margin: 0; display: grid; gap: 0.4rem; }
.mortel {
  display: flex; align-items: center; gap: 0.8rem; padding: 0.6rem 0.7rem; border-radius: 12px; color: inherit; text-decoration: none;
  border: 1px solid transparent; transition: background-color 0.15s, border-color 0.15s, transform 0.15s;
}
.mortel:hover { background: var(--surface-2); border-color: var(--bord); transform: translateX(3px); }
.quoi { display: flex; flex-direction: column; min-width: 0; flex: 1; }
.quoi strong { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.tues { color: var(--fatal); font-size: 0.85rem; white-space: nowrap; }
.tues strong { font-size: 1.1rem; }

.avertissement { display: flex; gap: 0.8rem; align-items: flex-start; background: var(--marque-doux); border-color: transparent; box-shadow: none; }
.avertissement svg { flex: none; color: var(--marque); margin-top: 0.1rem; }
.avertissement p { margin: 0; font-size: 0.9rem; }

@media (max-width: 1000px) {
  .chiffres { grid-template-columns: repeat(2, 1fr); }
  .grille.a, .grille.b { grid-template-columns: 1fr; }
}
@media (max-width: 720px) {
  .bandeau { padding: 1.4rem 1.25rem; }
  .reglages, .annee, .annee select { width: 100%; }
  .modes { width: 100%; justify-content: space-between; }
  .modes button { flex: 1; padding: 0.4rem 0.3rem; font-size: 0.8rem; }
  .chiffres { gap: 0.75rem; }
}
</style>
