<script setup>
import { onMounted, reactive, ref, watch } from 'vue';
import { lire } from '../api.js';
import { GRAVITES, MODES } from '../libelles.js';
import { VIDE } from '../filtres.js';

const props = defineProps({ modelValue: { type: Object, required: true } });
const emit = defineEmits(['update:modelValue']);

const saisie = reactive({ ...VIDE, ...props.modelValue });
const sources = ref([]);

watch(() => props.modelValue, (v) => Object.assign(saisie, VIDE, v));

onMounted(async () => {
  try {
    sources.value = await lire('/api/v1/sources');
  } catch {
    sources.value = [];
  }
});

function appliquer() {
  emit('update:modelValue', { ...saisie, severity: [...saisie.severity] });
}

function effacer() {
  Object.assign(saisie, VIDE, { severity: [] });
  appliquer();
}
</script>

<template>
  <form class="carte filtres" @submit.prevent="appliquer">
    <label>
      Mode
      <select v-model="saisie.mode" name="mode">
        <option value="">Tous</option>
        <option v-for="(libelle, code) in MODES" :key="code" :value="code">{{ libelle }}</option>
      </select>
    </label>
    <label>
      Du
      <input v-model="saisie.from" type="date" name="from" />
    </label>
    <label>
      Au
      <input v-model="saisie.to" type="date" name="to" />
    </label>
    <label>
      Pays
      <select v-model="saisie.country" name="country">
        <option value="">Tous</option>
        <option value="FR">France</option>
        <option value="US">États-Unis</option>
      </select>
    </label>
    <label>
      Source
      <select v-model="saisie.source" name="source">
        <option value="">Toutes</option>
        <option v-for="s in sources" :key="s.code" :value="s.code">{{ s.name }}</option>
      </select>
    </label>
    <fieldset>
      <legend>Gravité</legend>
      <label v-for="(libelle, code) in GRAVITES" :key="code" class="case">
        <input v-model="saisie.severity" type="checkbox" :value="code" /> {{ libelle }}
      </label>
    </fieldset>
    <fieldset>
      <legend>Inclure</legend>
      <label class="case"><input v-model="saisie.includeUnverified" type="checkbox" name="includeUnverified" /> non vérifiés</label>
      <label class="case"><input v-model="saisie.includeSimulated" type="checkbox" name="includeSimulated" /> simulés</label>
    </fieldset>
    <div class="actions">
      <button type="submit">Rechercher</button>
      <button type="button" class="secondaire" @click="effacer">Effacer</button>
    </div>
  </form>
</template>

<style scoped>
.filtres { display: grid; grid-template-columns: repeat(auto-fill, minmax(11rem, 1fr)); gap: 0.75rem; align-items: end; }
label { display: flex; flex-direction: column; gap: 0.25rem; font-size: 0.9rem; }
label.case { flex-direction: row; align-items: center; gap: 0.35rem; }
fieldset { border: 1px solid var(--bord); border-radius: 4px; padding: 0.4rem 0.6rem; margin: 0; grid-column: span 2; display: flex; flex-wrap: wrap; gap: 0.3rem 0.9rem; }
legend { font-size: 0.85rem; color: var(--discret); }
.actions { display: flex; gap: 0.5rem; }
@media (max-width: 640px) { fieldset { grid-column: auto; } }
</style>
