<script setup>
defineProps({ clair: { type: Boolean, default: false } });
</script>

<template>
  <span class="logo" :class="{ clair }">
    <svg viewBox="0 0 32 32" aria-hidden="true">
      <defs>
        <linearGradient id="logo-degrade" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stop-color="#3653f0" />
          <stop offset="1" stop-color="#0aa5b8" />
        </linearGradient>
      </defs>
      <path d="M16 2 4 7v8c0 7.5 5.1 13.4 12 15 6.9-1.6 12-7.5 12-15V7L16 2Z" fill="url(#logo-degrade)" />
      <path d="M10 19c3-6 9-6 12-10" stroke="#fff" stroke-width="2.6" fill="none" stroke-linecap="round" />
      <circle cx="10" cy="19" r="2.2" fill="#fff" />
      <circle cx="22" cy="9" r="2.2" fill="#fff" />
    </svg>
    <span class="nom">SafeTransport<strong>AI</strong></span>
  </span>
</template>

<style scoped>
.logo { display: inline-flex; align-items: center; gap: 0.55rem; font-family: var(--police-titre); font-weight: 700; font-size: 1.1rem; color: var(--texte); }
.logo.clair { color: #fff; }
svg { width: 1.9rem; height: 1.9rem; flex: none; }
strong { margin-left: 0.2rem; padding: 0 0.3rem; border-radius: 5px; font-size: 0.75em; background: var(--marque-doux); color: var(--marque); }
.clair strong { background: rgb(255 255 255 / 18%); color: #fff; }
</style>
