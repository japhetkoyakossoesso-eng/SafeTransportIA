<script setup>
import { LayoutDashboard, LogOut, Moon, Search, Sun } from 'lucide-vue-next';
import { computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { deconnexion, lireJeton, lireUtilisateur } from './api.js';
import Logo from './components/Logo.vue';
import ServiceStatus from './components/ServiceStatus.vue';
import { basculerTheme, theme } from './theme.js';

const route = useRoute();
const router = useRouter();
const connecte = computed(() => route.name && route.name !== 'connexion' && !!lireJeton());

const utilisateur = computed(() => (connecte.value ? lireUtilisateur().username || '' : ''));

function quitter() {
  deconnexion();
  router.push({ name: 'connexion' });
}
</script>

<template>
  <header v-if="connecte" class="entete">
    <div class="page barre">
      <router-link to="/" class="accueil" aria-label="Tableau de bord"><Logo /></router-link>
      <nav class="navigation" aria-label="Navigation principale">
        <router-link to="/" class="lien" exact-active-class="actif">
          <LayoutDashboard :size="17" aria-hidden="true" /><span>Tableau de bord</span>
        </router-link>
        <router-link to="/recherche" class="lien" active-class="actif">
          <Search :size="17" aria-hidden="true" /><span>Recherche</span>
        </router-link>
      </nav>
      <div class="compte">
        <button class="bouton discret" :aria-label="theme === 'sombre' ? 'Passer en mode clair' : 'Passer en mode sombre'"
                :title="theme === 'sombre' ? 'Mode clair' : 'Mode sombre'" @click="basculerTheme">
          <Sun v-if="theme === 'sombre'" :size="18" aria-hidden="true" />
          <Moon v-else :size="18" aria-hidden="true" />
        </button>
        <span class="avatar" :title="utilisateur" aria-hidden="true">{{ utilisateur.slice(0, 1).toUpperCase() }}</span>
        <span class="nom">{{ utilisateur }}</span>
        <button class="bouton discret" title="Se déconnecter" aria-label="Se déconnecter" @click="quitter">
          <LogOut :size="18" aria-hidden="true" />
        </button>
      </div>
    </div>
  </header>

  <router-view v-slot="{ Component, route: r }">
    <transition name="fondu" mode="out-in">
      <component :is="Component" :key="r.name" />
    </transition>
  </router-view>

  <footer v-if="connecte" class="page pied">
    <p>
      Aide à l'analyse : chaque chiffre cite sa source. Les données simulées ou non vérifiées sont étiquetées,
      et les nombres bruts ne sont pas des taux de risque.
    </p>
    <ul class="services">
      <ServiceStatus name="API" url="/api/v1/health" />
      <ServiceStatus name="IA" url="/ai/health" />
    </ul>
  </footer>
</template>

<style>
.entete {
  position: sticky; top: 0; z-index: 10;
  background: color-mix(in srgb, var(--surface) 82%, transparent);
  backdrop-filter: saturate(1.6) blur(12px);
  border-bottom: 1px solid var(--bord);
}
.entete .barre { display: flex; align-items: center; gap: 1.5rem; padding-top: 0.6rem; padding-bottom: 0.6rem; }
.accueil { text-decoration: none; }
.navigation { display: flex; gap: 0.25rem; flex: 1; }
.lien {
  display: inline-flex; align-items: center; gap: 0.45rem; padding: 0.45rem 0.8rem; border-radius: 10px;
  color: var(--discret); text-decoration: none; font-weight: 600; font-size: 0.92rem; transition: background-color 0.15s, color 0.15s;
}
.lien:hover { color: var(--texte); background: var(--surface-2); }
.lien.actif { color: var(--marque); background: var(--marque-doux); }
.compte { display: flex; align-items: center; gap: 0.4rem; font-size: 0.9rem; }
.avatar {
  display: grid; place-items: center; width: 2rem; height: 2rem; border-radius: 50%;
  background: var(--degrade); color: #fff; font-weight: 700; font-size: 0.85rem;
}
.compte .nom { font-weight: 600; }
.page.pied { display: flex; justify-content: space-between; gap: 1rem; flex-wrap: wrap; color: var(--discret); font-size: 0.82rem; border-top: 1px solid var(--bord); padding-top: 1.25rem; }
.pied p { margin: 0; max-width: 44rem; }
.services { display: flex; gap: 1.25rem; padding: 0; margin: 0; list-style: none; }

@media (max-width: 720px) {
  .entete .barre { gap: 0.5rem; }
  .accueil .nom { display: none; }
  .navigation { justify-content: center; }
  .lien span, .compte .nom { display: none; }
  .lien { padding: 0.55rem 0.75rem; }
}
</style>
