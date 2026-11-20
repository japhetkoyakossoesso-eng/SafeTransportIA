<script setup>
import { RotateCcw, Search } from 'lucide-vue-next';
import { onMounted, reactive, ref, watch } from 'vue';
import { lire } from '../api.js';
import { GRAVITES, MODES } from '../libelles.js';
import { VIDE } from '../filtres.js';
import IconeMode from './IconeMode.vue';

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
    <fieldset>
      <legend>Mode de transport</legend>
      <div class="pastilles">
        <label class="pastille" :class="{ choisi: !saisie.mode }">
          <input v-model="saisie.mode" type="radio" name="mode" value="" class="invisible" />Tous
        </label>
        <label v-for="(libelle, code) in MODES" :key="code" class="pastille" :class="{ choisi: saisie.mode === code }">
          <input v-model="saisie.mode" type="radio" name="mode" :value="code" class="invisible" />
          <IconeMode :mode="code" :taille="13" />{{ libelle }}
        </label>
      </div>
    </fieldset>

    <fieldset>
      <legend>Période</legend>
      <div class="periode">
        <label>Du <input v-model="saisie.from" type="date" name="from" /></label>
        <label>Au <input v-model="saisie.to" type="date" name="to" /></label>
      </div>
    </fieldset>

    <div class="deux">
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
    </div>

    <fieldset>
      <legend>Gravité</legend>
      <div class="pastilles">
        <label v-for="(libelle, code) in GRAVITES" :key="code" class="pastille" :class="[`gravite-${code}`, { choisi: saisie.severity.includes(code) }]">
          <input v-model="saisie.severity" type="checkbox" :value="code" class="invisible" />
          <span class="point" aria-hidden="true" />{{ libelle }}
        </label>
      </div>
    </fieldset>

    <fieldset>
      <legend>Inclure aussi</legend>
      <label class="interrupteur">
        <input v-model="saisie.includeUnverified" type="checkbox" name="includeUnverified" />
        <span>Non vérifiés <small class="discret">imports pas encore revus</small></span>
      </label>
      <label class="interrupteur">
        <input v-model="saisie.includeSimulated" type="checkbox" name="includeSimulated" />
        <span>Simulés <small class="discret">jeu de démonstration</small></span>
      </label>
    </fieldset>

    <div class="actions">
      <button type="submit" class="bouton"><Search :size="16" aria-hidden="true" />Rechercher</button>
      <button type="button" class="bouton secondaire" @click="effacer"><RotateCcw :size="16" aria-hidden="true" />Effacer</button>
    </div>
  </form>
</template>

<style scoped>
.filtres { display: flex; flex-direction: column; gap: 1.1rem; }
fieldset { border: 0; padding: 0; margin: 0; min-width: 0; }
legend { font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.06em; font-weight: 700; color: var(--discret); margin-bottom: 0.5rem; }
label { display: flex; flex-direction: column; gap: 0.3rem; font-size: 0.85rem; font-weight: 600; }
.deux { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 0.6rem; }
.periode { display: grid; grid-template-columns: repeat(auto-fit, minmax(9rem, 1fr)); gap: 0.6rem; }
.periode label { flex-direction: row; align-items: center; gap: 0.5rem; }
.periode input { flex: 1; min-width: 0; }
.pastilles { display: flex; flex-wrap: wrap; gap: 0.4rem; }
.pastille {
  flex-direction: row; align-items: center; gap: 0.35rem; padding: 0.3rem 0.65rem; border-radius: 999px; cursor: pointer;
  border: 1px solid var(--bord); background: var(--surface); font-size: 0.82rem; transition: all 0.15s;
}
.pastille :deep(.icone-mode) { width: 1.4rem; height: 1.4rem; border-radius: 50%; }
.pastille:hover { border-color: color-mix(in srgb, var(--marque) 50%, var(--bord)); }
.pastille.choisi { border-color: var(--marque); background: var(--marque-doux); color: var(--marque); }
.pastille:has(input:focus-visible) { outline: 3px solid color-mix(in srgb, var(--marque) 55%, transparent); outline-offset: 2px; }
.point { width: 0.5rem; height: 0.5rem; border-radius: 50%; background: var(--g); }
.pastille[class*='gravite-'].choisi { border-color: var(--g); color: var(--g); background: color-mix(in srgb, var(--g) 12%, transparent); }
.interrupteur { flex-direction: row; align-items: center; gap: 0.6rem; padding: 0.35rem 0; cursor: pointer; }
.interrupteur span { display: flex; flex-direction: column; line-height: 1.25; }
.interrupteur small { font-weight: 400; }
.interrupteur input {
  appearance: none; width: 2.3rem; height: 1.3rem; border-radius: 999px; background: var(--bord); position: relative;
  cursor: pointer; flex: none; transition: background-color 0.2s; border: 0; padding: 0;
}
.interrupteur input::after {
  content: ''; position: absolute; top: 0.15rem; left: 0.15rem; width: 1rem; height: 1rem; border-radius: 50%;
  background: #fff; box-shadow: 0 1px 3px rgb(0 0 0 / 30%); transition: transform 0.2s;
}
.interrupteur input:checked { background: var(--marque); }
.interrupteur input:checked::after { transform: translateX(1rem); }
.actions { display: grid; grid-template-columns: 1fr auto; gap: 0.5rem; }
</style>
