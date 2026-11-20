<script setup>
import {
  ArrowLeft, CalendarClock, CircleAlert, CircleCheck, CircleHelp, Database, FlaskConical, Lightbulb, MapPin, ShieldAlert,
} from 'lucide-vue-next';
import { ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { NonConnecte, lire } from '../api.js';
import Etiquettes from '../components/Etiquettes.vue';
import IconeMode from '../components/IconeMode.vue';
import { ASSERTIONS, GRAVITES, MODES, PRECISIONS, STATUTS, date, heure } from '../libelles.js';

const props = defineProps({ id: { type: String, required: true } });
const router = useRouter();
const accident = ref(null);
const erreur = ref('');

const ICONES = { established: CircleCheck, probable: CircleHelp, hypothesis: Lightbulb };
const ADJECTIFS = { road: 'routier', air: 'aérien', rail: 'ferroviaire', maritime: 'maritime' };
const CONFIANCE = { high: 'élevée', medium: 'moyenne', low: 'faible' };

watch(() => props.id, async (id) => {
  erreur.value = '';
  try {
    accident.value = await lire(`/api/v1/accidents/${id}`);
  } catch (e) {
    if (e instanceof NonConnecte) router.push({ name: 'connexion' });
    else erreur.value = e.message;
  }
}, { immediate: true });

function lieu(l) {
  if (!l) return 'inconnu';
  return [l.siteName, l.municipality, l.inseeCode && `commune ${l.inseeCode}`, l.department && `dép. ${l.department}`,
    l.region, l.country].filter(Boolean).join(', ') || 'inconnu';
}

function retour() {
  if (window.history.state?.back) router.back();
  else router.push({ name: 'recherche' });
}
</script>

<template>
  <main class="page fiche">
    <button class="bouton discret retour" @click="retour"><ArrowLeft :size="16" aria-hidden="true" />Retour</button>
    <p v-if="erreur" class="erreur"><CircleAlert :size="17" aria-hidden="true" />{{ erreur }}</p>

    <div v-if="!accident && !erreur" class="attente">
      <div class="squelette" style="height: 9rem" />
      <div class="squelette" style="height: 18rem" />
    </div>

    <template v-if="accident">
      <div v-if="accident.simulated" class="bandeau-simule apparition" role="note">
        <FlaskConical :size="20" aria-hidden="true" />
        <p><strong>Donnée simulée</strong> : elle n'existe pas dans la réalité et sert uniquement aux tests et à la démonstration.</p>
      </div>
      <div v-else-if="accident.validationStatus !== 'validated'" class="bandeau-revue apparition" role="note">
        <ShieldAlert :size="20" aria-hidden="true" />
        <p>Cet accident n'a pas encore été validé par un responsable.</p>
      </div>

      <section class="carte en-tete apparition" :class="`mode-${accident.mode}`">
        <IconeMode :mode="accident.mode" :taille="28" class="grande-icone" />
        <div class="identite">
          <h1>Accident {{ ADJECTIFS[accident.mode] || '' }} du {{ date(accident.date) }}</h1>
          <p class="lieu"><MapPin :size="16" aria-hidden="true" />{{ lieu(accident.location) }}</p>
          <div class="badges">
            <span :class="`gravite gravite-${accident.severity}`">{{ GRAVITES[accident.severity] }}</span>
            <Etiquettes :simulated="accident.simulated" :validation-status="accident.validationStatus" />
          </div>
        </div>
      </section>

      <section class="victimes apparition">
        <div class="victime tues"><span class="chiffre">{{ accident.fatalities ?? '?' }}</span>tué(s)</div>
        <div class="victime graves"><span class="chiffre">{{ accident.seriousInjuries ?? '?' }}</span>blessé(s) grave(s)</div>
        <div class="victime legers"><span class="chiffre">{{ accident.minorInjuries ?? '?' }}</span>blessé(s) léger(s)</div>
      </section>

      <div class="colonnes">
        <section class="carte apparition">
          <h2><CalendarClock :size="18" aria-hidden="true" />Circonstances</h2>
          <dl>
            <dt>Date et heure</dt>
            <dd>{{ date(accident.date) }}, {{ heure(accident.occurredAt) }}</dd>
            <dt>Mode</dt>
            <dd>{{ MODES[accident.mode] || accident.mode }}<span v-if="accident.category" class="discret"> · {{ accident.category }}</span></dd>
            <dt>Lieu</dt>
            <dd>
              {{ lieu(accident.location) }}
              <span class="discret">({{ PRECISIONS[accident.location?.precision] || 'précision inconnue' }})</span>
            </dd>
            <dt>Gravité</dt>
            <dd>
              {{ GRAVITES[accident.severity] }}
              <span class="discret"> (libellé de la source : {{ accident.severityLabel || 'aucun' }})</span>
            </dd>
            <template v-if="accident.summary">
              <dt>Résumé</dt>
              <dd>{{ accident.summary }}</dd>
            </template>
          </dl>
        </section>

        <section class="carte apparition">
          <h2><Database :size="18" aria-hidden="true" />Source et traçabilité</h2>
          <dl>
            <dt>Source</dt>
            <dd>{{ accident.source?.name }}</dd>
            <dt>Licence</dt>
            <dd>{{ accident.source?.license || 'non précisée' }}</dd>
            <dt>Référence</dt>
            <dd><code>{{ accident.source?.sourceRef }}</code></dd>
            <template v-if="accident.source?.importJobId">
              <dt>Import</dt>
              <dd>n°{{ accident.source.importJobId }}</dd>
            </template>
            <dt>Statut</dt>
            <dd>{{ STATUTS[accident.validationStatus] }}</dd>
            <dt>Confiance</dt>
            <dd>{{ CONFIANCE[accident.confidence] || accident.confidence }}</dd>
          </dl>
        </section>
      </div>

      <section class="carte apparition">
        <div class="entete-carte">
          <h2>Facteurs</h2>
          <ul class="legende-niveaux" aria-label="Niveaux de certitude">
            <li v-for="(libelle, code) in ASSERTIONS" :key="code" :class="`assertion-${code}`">
              <component :is="ICONES[code]" :size="14" aria-hidden="true" />{{ libelle }}
            </li>
          </ul>
        </div>
        <p v-if="!accident.factors.length" class="discret">Aucun facteur renseigné par la source.</p>
        <ul v-else class="facteurs">
          <li v-for="(f, i) in accident.factors" :key="i" :class="`assertion-${f.assertion}`">
            <component :is="ICONES[f.assertion] || CircleHelp" :size="20" class="icone-facteur" aria-hidden="true" />
            <div>
              <span class="etiquette">{{ ASSERTIONS[f.assertion] || f.assertion }}</span>
              <p>{{ f.description }}</p>
              <p class="discret">{{ f.category }}, selon {{ f.statedBy }}</p>
            </div>
          </li>
        </ul>
      </section>
    </template>
  </main>
</template>

<style scoped>
.fiche { display: grid; gap: 1rem; max-width: 62rem; }
.retour { justify-self: start; margin-left: -0.6rem; }
.attente { display: grid; gap: 1rem; }
.bandeau-simule, .bandeau-revue { display: flex; gap: 0.75rem; align-items: center; padding: 0.9rem 1.1rem; border-radius: var(--rayon); }
.bandeau-simule p, .bandeau-revue p { margin: 0; }
.bandeau-simule {
  color: var(--simule); border: 1.5px dashed var(--simule);
  background: repeating-linear-gradient(-45deg, var(--simule-doux), var(--simule-doux) 12px, transparent 12px, transparent 24px), var(--surface);
}
.bandeau-revue { color: var(--avertissement); background: var(--avertissement-doux); }

.en-tete { display: flex; gap: 1.25rem; align-items: center; position: relative; overflow: hidden; }
.en-tete::before { content: ''; position: absolute; inset: 0 auto 0 0; width: 5px; background: var(--m); }
.grande-icone { font-size: 1.6rem; border-radius: 16px; }
h1 { margin: 0; font-size: clamp(1.35rem, 2.5vw, 1.8rem); font-weight: 800; }
.lieu { display: flex; align-items: center; gap: 0.35rem; margin: 0.3rem 0 0.6rem; color: var(--discret); }
.lieu svg { flex: none; }
.badges { display: flex; flex-wrap: wrap; gap: 0.4rem; align-items: center; }

.victimes { display: grid; grid-template-columns: repeat(3, 1fr); gap: 1rem; }
.victime {
  display: flex; flex-direction: column; padding: 1rem 1.2rem; border-radius: var(--rayon); font-size: 0.88rem; font-weight: 600;
  color: var(--v); background: color-mix(in srgb, var(--v) 10%, var(--surface)); border: 1px solid color-mix(in srgb, var(--v) 25%, transparent);
}
.victime .chiffre { font-size: 2rem; font-weight: 800; line-height: 1.1; }
.tues { --v: var(--fatal); }
.graves { --v: var(--serious); }
.legers { --v: var(--minor); }

.colonnes { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
h2 { display: flex; align-items: center; gap: 0.5rem; margin-bottom: 0.9rem; }
h2 svg { color: var(--marque); }
.entete-carte h2 { margin: 0; }
dl { display: grid; grid-template-columns: 8.5rem 1fr; gap: 0.6rem 1rem; margin: 0; font-size: 0.92rem; }
dt { color: var(--discret); }
dd { margin: 0; }
code { background: var(--surface-2); padding: 0.05rem 0.35rem; border-radius: 5px; font-size: 0.85em; }

.legende-niveaux { display: flex; flex-wrap: wrap; gap: 0.75rem; list-style: none; padding: 0; margin: 0; font-size: 0.78rem; }
.legende-niveaux li { display: inline-flex; align-items: center; gap: 0.25rem; color: var(--a); font-weight: 600; }
.facteurs { list-style: none; padding: 0; margin: 0; display: grid; gap: 0.6rem; }
.facteurs li { display: flex; gap: 0.8rem; padding: 0.85rem 1rem; border-radius: 12px; background: var(--surface-2); border-left: 3px solid var(--a); }
.facteurs p { margin: 0.3rem 0 0; }
.facteurs .discret { font-size: 0.8rem; }
.icone-facteur { flex: none; color: var(--a); margin-top: 0.1rem; }
.facteurs .etiquette { color: var(--a); background: color-mix(in srgb, var(--a) 14%, transparent); }
.assertion-established { --a: var(--succes); }
.assertion-probable { --a: var(--serious); }
.assertion-hypothesis { --a: var(--discret); }
.facteurs .assertion-hypothesis { border-left-style: dashed; }

@media (max-width: 720px) {
  .en-tete { flex-direction: column; align-items: flex-start; }
  .victimes { gap: 0.5rem; }
  .victime { padding: 0.75rem; font-size: 0.75rem; }
  .victime .chiffre { font-size: 1.5rem; }
  .colonnes { grid-template-columns: 1fr; }
  dl { grid-template-columns: 1fr; gap: 0.15rem; }
  dd { margin-bottom: 0.5rem; }
}
</style>
