<script setup>
import { ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { connexion } from '../api.js';

const route = useRoute();
const router = useRouter();
const username = ref('');
const password = ref('');
const erreur = ref('');
const enCours = ref(false);

async function valider() {
  erreur.value = '';
  enCours.value = true;
  try {
    await connexion(username.value, password.value);
    router.push(route.query.retour || '/');
  } catch (e) {
    erreur.value = e.message;
  } finally {
    enCours.value = false;
  }
}
</script>

<template>
  <main class="page">
    <form class="carte connexion" @submit.prevent="valider">
      <h1>Connexion</h1>
      <label>Identifiant <input v-model="username" name="username" autocomplete="username" required /></label>
      <label>Mot de passe <input v-model="password" name="password" type="password" autocomplete="current-password" required /></label>
      <p v-if="erreur" class="erreur">{{ erreur }}</p>
      <button type="submit" :disabled="enCours">Se connecter</button>
      <p class="discret">Comptes de démonstration : analyste.demo, resp.securite.demo, admin.demo (mot de passe demo).</p>
    </form>
  </main>
</template>

<style scoped>
.connexion { max-width: 24rem; margin: 2rem auto; display: flex; flex-direction: column; gap: 0.8rem; }
label { display: flex; flex-direction: column; gap: 0.25rem; }
h1 { margin: 0; font-size: 1.3rem; }
</style>
