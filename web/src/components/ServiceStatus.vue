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
  <li>
    <strong>{{ name }}</strong> : <span class="state">{{ state }}</span>
    <small v-if="detail"> ({{ detail }})</small>
  </li>
</template>
