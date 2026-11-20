<script setup>
import { ChevronRight } from 'lucide-vue-next';
import { useRouter } from 'vue-router';
import { GRAVITES, MODES, date, lieuCourt as lieu } from '../libelles.js';
import Etiquettes from './Etiquettes.vue';
import IconeMode from './IconeMode.vue';

defineProps({ accidents: { type: Array, required: true } });
const router = useRouter();

</script>

<template>
  <table class="adaptatif liste">
    <thead>
      <tr>
        <th>Date</th>
        <th>Mode</th>
        <th>Lieu</th>
        <th>Gravité</th>
        <th class="nombre">Tués</th>
        <th class="nombre">Blessés graves</th>
        <th>Source</th>
        <th><span class="invisible">Ouvrir</span></th>
      </tr>
    </thead>
    <tbody>
      <tr v-for="a in accidents" :key="a.id" @click="router.push(`/accidents/${a.id}`)">
        <td data-libelle="Date">
          <router-link :to="`/accidents/${a.id}`" class="date" @click.stop>{{ date(a.date) }}</router-link>
          <Etiquettes :simulated="a.simulated" :validation-status="a.validationStatus" />
        </td>
        <td data-libelle="Mode"><span class="mode"><IconeMode :mode="a.mode" :taille="15" />{{ MODES[a.mode] || a.mode }}</span></td>
        <td data-libelle="Lieu" class="lieu">{{ lieu(a) || '—' }}</td>
        <td data-libelle="Gravité"><span :class="`gravite gravite-${a.severity}`">{{ GRAVITES[a.severity] }}</span></td>
        <td data-libelle="Tués" class="nombre chiffre" :class="{ fort: a.fatalities > 0 }">{{ a.fatalities ?? '?' }}</td>
        <td data-libelle="Blessés graves" class="nombre chiffre">{{ a.seriousInjuries ?? '?' }}</td>
        <td data-libelle="Source"><code class="source">{{ a.source }}</code></td>
        <td class="fleche" aria-hidden="true"><ChevronRight :size="18" /></td>
      </tr>
    </tbody>
  </table>
</template>

<style scoped>
tbody tr { cursor: pointer; }
.date { font-weight: 700; text-decoration: none; color: var(--texte); margin-right: 0.4rem; }
tr:hover .date { color: var(--marque); }
.mode { display: inline-flex; align-items: center; gap: 0.5rem; }
.lieu { max-width: 16rem; }
.nombre { text-align: right; }
.fort { color: var(--fatal); font-weight: 700; }
.source { font-size: 0.78rem; background: var(--surface-2); padding: 0.1rem 0.4rem; border-radius: 6px; color: var(--discret); }
.fleche { color: var(--discret); width: 1.5rem; }
tr:hover .fleche { color: var(--marque); }
@media (max-width: 720px) {
  .fleche { display: none !important; }
  .lieu { max-width: none; }
  td:first-child { font-size: 1rem; }
}
</style>
