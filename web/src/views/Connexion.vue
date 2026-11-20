<script setup>
import { CircleAlert, Eye, EyeOff, Layers, LockKeyhole, ShieldCheck, Scale, UserRound } from 'lucide-vue-next';
import { ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { connexion } from '../api.js';
import Logo from '../components/Logo.vue';

const COMPTES = [
  { username: 'analyste.demo', role: 'Analyste' },
  { username: 'resp.securite.demo', role: 'Resp. sécurité' },
  { username: 'admin.demo', role: 'Admin' },
];

const route = useRoute();
const router = useRouter();
const username = ref('');
const password = ref('');
const voir = ref(false);
const erreur = ref('');
const enCours = ref(false);

function remplir(compte) {
  username.value = compte.username;
  password.value = 'demo';
}

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
  <main class="ecran">
    <section class="vitrine">
      <svg class="trajets" viewBox="0 0 600 600" aria-hidden="true">
        <path d="M-20 470 C 120 380, 220 520, 340 400 S 520 260, 640 300" />
        <path d="M-20 200 C 140 260, 260 120, 380 180 S 540 120, 640 60" />
        <path d="M80 640 C 120 520, 260 480, 300 380 S 420 160, 520 -20" class="pointille" />
        <circle cx="340" cy="400" r="5" /><circle cx="380" cy="180" r="5" /><circle cx="300" cy="380" r="4" />
      </svg>
      <div class="contenu-vitrine">
        <Logo clair />
        <h1>Comprendre les accidents de transport pour mieux les prévenir.</h1>
        <p class="accroche">Route, aérien, ferroviaire, maritime : une base unique, alimentée par des sources publiques et vérifiée avant publication.</p>
        <ul class="atouts">
          <li><ShieldCheck :size="20" aria-hidden="true" /><span><strong>Sources citées</strong> sur chaque chiffre et chaque graphique.</span></li>
          <li><Scale :size="20" aria-hidden="true" /><span><strong>Faits, probabilités, hypothèses</strong> toujours distingués.</span></li>
          <li><Layers :size="20" aria-hidden="true" /><span><strong>Données simulées</strong> clairement étiquetées, jamais mélangées.</span></li>
        </ul>
      </div>
    </section>

    <section class="formulaire">
      <form class="carte connexion apparition" :class="{ secoue: erreur }" @submit.prevent="valider">
        <div>
          <h2>Connexion</h2>
          <p class="discret">Accédez au tableau de bord et à la recherche.</p>
        </div>
        <label>
          <span>Identifiant</span>
          <span class="champ">
            <UserRound :size="17" aria-hidden="true" />
            <input v-model="username" name="username" autocomplete="username" required placeholder="analyste.demo" />
          </span>
        </label>
        <label>
          <span>Mot de passe</span>
          <span class="champ">
            <LockKeyhole :size="17" aria-hidden="true" />
            <input v-model="password" name="password" :type="voir ? 'text' : 'password'" autocomplete="current-password" required />
            <button type="button" class="oeil" :aria-label="voir ? 'Masquer le mot de passe' : 'Afficher le mot de passe'" @click="voir = !voir">
              <EyeOff v-if="voir" :size="17" aria-hidden="true" /><Eye v-else :size="17" aria-hidden="true" />
            </button>
          </span>
        </label>
        <p v-if="erreur" class="erreur" role="alert"><CircleAlert :size="17" aria-hidden="true" />{{ erreur }}</p>
        <button type="submit" class="bouton large" :disabled="enCours">
          <span v-if="enCours" class="rond" aria-hidden="true" />
          {{ enCours ? 'Connexion…' : 'Se connecter' }}
        </button>
        <div class="demo">
          <p class="discret">Comptes de démonstration, mot de passe <code>demo</code></p>
          <div class="comptes">
            <button v-for="c in COMPTES" :key="c.username" type="button" class="compte-demo" @click="remplir(c)">
              <strong>{{ c.role }}</strong><span>{{ c.username }}</span>
            </button>
          </div>
        </div>
      </form>
    </section>
  </main>
</template>

<style scoped>
.ecran { display: grid; grid-template-columns: minmax(0, 1.1fr) minmax(0, 1fr); min-height: 100vh; }
.vitrine { position: relative; overflow: hidden; background: var(--degrade); color: #fff; display: flex; align-items: center; padding: 3rem; }
.trajets { position: absolute; inset: 0; width: 100%; height: 100%; opacity: 0.35; }
.trajets path { fill: none; stroke: #fff; stroke-width: 1.5; stroke-linecap: round; stroke-dasharray: 900; animation: trace 4s ease-out both; }
.trajets .pointille { stroke-dasharray: 4 10; animation: none; opacity: 0.7; }
.trajets circle { fill: #fff; }
@keyframes trace { from { stroke-dashoffset: 900; } to { stroke-dashoffset: 0; } }
.contenu-vitrine { position: relative; max-width: 32rem; }
h1 { font-size: clamp(1.7rem, 3vw, 2.5rem); margin: 2.5rem 0 1rem; font-weight: 800; letter-spacing: -0.02em; }
.accroche { font-size: 1.05rem; opacity: 0.88; margin: 0 0 2rem; }
.atouts { list-style: none; padding: 0; margin: 0; display: grid; gap: 0.9rem; }
.atouts li {
  display: flex; gap: 0.75rem; align-items: flex-start; padding: 0.8rem 1rem; border-radius: 12px;
  background: rgb(255 255 255 / 10%); border: 1px solid rgb(255 255 255 / 16%); backdrop-filter: blur(6px);
}
.atouts svg { flex: none; margin-top: 0.1rem; }

.formulaire { display: grid; place-items: center; padding: 2rem 1.25rem; }
.connexion { width: 100%; max-width: 25rem; display: flex; flex-direction: column; gap: 1rem; padding: 2rem; box-shadow: var(--ombre-forte); }
.connexion h2 { font-size: 1.5rem; }
.connexion .discret { margin: 0.25rem 0 0; }
label { display: flex; flex-direction: column; gap: 0.35rem; font-weight: 600; font-size: 0.88rem; }
.champ { position: relative; display: flex; align-items: center; }
.champ > svg { position: absolute; left: 0.75rem; color: var(--discret); pointer-events: none; }
.champ input { padding-left: 2.3rem; font-weight: 400; }
.oeil { position: absolute; right: 0.4rem; border: 0; background: none; color: var(--discret); cursor: pointer; padding: 0.3rem; display: grid; }
.large { width: 100%; padding: 0.75rem; font-size: 1rem; }
.rond { width: 1rem; height: 1rem; border: 2px solid currentColor; border-right-color: transparent; border-radius: 50%; animation: tourne 0.7s linear infinite; }
@keyframes tourne { to { transform: rotate(360deg); } }
.secoue { animation: secoue 0.35s; }
@keyframes secoue { 25% { transform: translateX(-6px); } 75% { transform: translateX(6px); } }
.demo { border-top: 1px solid var(--bord); padding-top: 1rem; }
.demo .discret { margin: 0 0 0.6rem; }
.comptes { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 0.5rem; }
.compte-demo {
  display: flex; flex-direction: column; align-items: flex-start; gap: 0.1rem; padding: 0.5rem 0.6rem; border-radius: 10px;
  border: 1px solid var(--bord); background: var(--surface-2); cursor: pointer; text-align: left; font-size: 0.75rem; transition: border-color 0.15s, transform 0.15s;
}
.compte-demo:hover { border-color: var(--marque); transform: translateY(-1px); }
.compte-demo strong { font-size: 0.8rem; }
.compte-demo span { color: var(--discret); overflow: hidden; text-overflow: ellipsis; max-width: 100%; }
code { background: var(--surface-2); padding: 0.05rem 0.3rem; border-radius: 4px; }

@media (max-width: 900px) {
  .ecran { grid-template-columns: minmax(0, 1fr); }
  .vitrine { padding: 2rem 1.25rem 2.5rem; }
  h1 { margin: 1.25rem 0 0; font-size: 1.45rem; }
  .atouts, .accroche { display: none; }
  .formulaire { margin-top: -1.5rem; align-items: start; }
  .connexion { padding: 1.5rem; }
}
</style>
