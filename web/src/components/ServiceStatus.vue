<script setup>
import { onMounted, ref } from 'vue';

const props = defineProps({
  name: { type: String, required: true },
  url: { type: String, required: true },
});

const state = ref('…');
const detail = ref('');

onMounted(async () => {
  try {
    const body = await (await fetch(props.url)).json();
    state.value = body.status;
    detail.value = body.database ?? '';
  } catch {
    state.value = 'injoignable';
  }
});
</script>

<template>
  <li class="service" :class="{ ok: state === 'ok', ko: state === 'injoignable' }" :title="detail">
    <span class="point" aria-hidden="true" />
    <strong>{{ name }}</strong> <span class="state">{{ state }}</span>
  </li>
</template>

<style scoped>
.service { display: inline-flex; align-items: center; gap: 0.35rem; }
.point { width: 0.5rem; height: 0.5rem; border-radius: 50%; background: var(--unknown); }
.ok .point { background: var(--succes); box-shadow: 0 0 0 3px color-mix(in srgb, var(--succes) 25%, transparent); }
.ko .point { background: var(--fatal); }
</style>
