<script setup>
import { GRAVITES, MODES, date } from '../libelles.js';
import Etiquettes from './Etiquettes.vue';

defineProps({ accidents: { type: Array, required: true } });

function lieu(a) {
  const departement = /^\d/.test(a.department || '') ? `dép. ${a.department}` : a.department;
  return [a.municipality, departement, a.country].filter(Boolean).join(', ');
}
</script>

<template>
  <table class="adaptatif">
    <thead>
      <tr>
        <th>Date</th>
        <th>Mode</th>
        <th>Lieu</th>
        <th>Gravité</th>
        <th>Tués</th>
        <th>Blessés graves</th>
        <th>Source</th>
        <th></th>
      </tr>
    </thead>
    <tbody>
      <tr v-for="a in accidents" :key="a.id">
        <td data-libelle="Date"><router-link :to="`/accidents/${a.id}`">{{ date(a.date) }}</router-link></td>
        <td data-libelle="Mode">{{ MODES[a.mode] || a.mode }}</td>
        <td data-libelle="Lieu">{{ lieu(a) }}</td>
        <td data-libelle="Gravité" :class="`gravite-${a.severity}`">{{ GRAVITES[a.severity] }}</td>
        <td data-libelle="Tués">{{ a.fatalities ?? '?' }}</td>
        <td data-libelle="Blessés graves">{{ a.seriousInjuries ?? '?' }}</td>
        <td data-libelle="Source">{{ a.source }}</td>
        <td data-libelle="">
          <Etiquettes :simulated="a.simulated" :validation-status="a.validationStatus" />
        </td>
      </tr>
    </tbody>
  </table>
</template>
