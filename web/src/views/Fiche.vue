<script setup>
import { ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { NonConnecte, lire } from '../api.js';
import Etiquettes from '../components/Etiquettes.vue';
import { ASSERTIONS, GRAVITES, MODES, PRECISIONS, STATUTS, date, heure } from '../libelles.js';

const props = defineProps({ id: { type: String, required: true } });
const router = useRouter();
const accident = ref(null);
const erreur = ref('');

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
    l.region, l.country].filter(Boolean).join(', ');
}
</script>

<template>
  <main class="page">
    <p><a href="#" @click.prevent="router.back()">← Retour à la recherche</a></p>
    <p v-if="erreur" class="erreur">{{ erreur }}</p>
    <article v-if="accident" class="carte">
      <h1>
        Accident du {{ date(accident.date) }}
        <Etiquettes :simulated="accident.simulated" :validation-status="accident.validationStatus" />
      </h1>
      <p v-if="accident.simulated" class="erreur">Donnée simulée : elle n'existe pas dans la réalité.</p>
      <p v-else-if="accident.validationStatus !== 'validated'" class="erreur">
        Cet accident n'a pas encore été validé par un responsable.
      </p>

      <dl>
        <dt>Date et heure</dt>
        <dd>{{ date(accident.date) }}, {{ heure(accident.occurredAt) }}</dd>
        <dt>Mode</dt>
        <dd>{{ MODES[accident.mode] || accident.mode }}<span v-if="accident.category"> ({{ accident.category }})</span></dd>
        <dt>Lieu</dt>
        <dd>
          {{ lieu(accident.location) }}
          <span class="discret">({{ PRECISIONS[accident.location?.precision] || 'précision inconnue' }})</span>
        </dd>
        <dt>Gravité</dt>
        <dd>
          <span :class="`gravite-${accident.severity}`">{{ GRAVITES[accident.severity] }}</span>
          <span class="discret"> (libellé de la source : {{ accident.severityLabel || 'aucun' }})</span>
        </dd>
        <dt>Victimes</dt>
        <dd>
          {{ accident.fatalities ?? '?' }} tué(s), {{ accident.seriousInjuries ?? '?' }} blessé(s) grave(s),
          {{ accident.minorInjuries ?? '?' }} blessé(s) léger(s)
        </dd>
        <dt>Source</dt>
        <dd>
          {{ accident.source?.name }} ({{ accident.source?.license }}), référence {{ accident.source?.sourceRef }}
          <span v-if="accident.source?.importJobId" class="discret">, import n°{{ accident.source.importJobId }}</span>
        </dd>
        <dt>Statut</dt>
        <dd>{{ STATUTS[accident.validationStatus] }}, confiance {{ accident.confidence }}</dd>
        <template v-if="accident.summary">
          <dt>Résumé</dt>
          <dd>{{ accident.summary }}</dd>
        </template>
      </dl>

      <h2>Facteurs</h2>
      <p v-if="!accident.factors.length" class="discret">Aucun facteur renseigné.</p>
      <ul v-else class="facteurs">
        <li v-for="(f, i) in accident.factors" :key="i">
          <span class="etiquette" :class="`assertion-${f.assertion}`">{{ ASSERTIONS[f.assertion] || f.assertion }}</span>
          {{ f.description }} <span class="discret">({{ f.category }}, selon {{ f.statedBy }})</span>
        </li>
      </ul>
    </article>
  </main>
</template>

<style scoped>
h1 { font-size: 1.3rem; display: flex; flex-wrap: wrap; align-items: center; gap: 0.5rem; }
h2 { font-size: 1.1rem; }
dl { display: grid; grid-template-columns: 10rem 1fr; gap: 0.5rem 1rem; }
dt { color: var(--discret); }
dd { margin: 0; }
.facteurs { padding-left: 1rem; }
.facteurs li { margin-bottom: 0.4rem; }
.assertion-established { background: #d7f0dd; color: #1b5e2a; }
.assertion-probable { background: #fff0c2; color: #6a4500; }
.assertion-hypothesis { background: #eceef2; color: #3c4454; }
@media (max-width: 640px) { dl { grid-template-columns: 1fr; } dd { margin-bottom: 0.4rem; } }
</style>
