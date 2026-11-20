import { createRouter, createWebHistory } from 'vue-router';
import { lireJeton } from './api.js';
import Connexion from './views/Connexion.vue';
import Fiche from './views/Fiche.vue';
import Recherche from './views/Recherche.vue';
import TableauDeBord from './views/TableauDeBord.vue';

export const routes = [
  { path: '/connexion', name: 'connexion', component: Connexion, meta: { publique: true } },
  { path: '/', name: 'tableau', component: TableauDeBord },
  { path: '/recherche', name: 'recherche', component: Recherche },
  { path: '/accidents/:id', name: 'fiche', component: Fiche, props: true },
];

export function creerRouteur(historique = createWebHistory()) {
  const routeur = createRouter({
    history: historique,
    routes,
    scrollBehavior: (vers, depuis) => (vers.path !== depuis.path ? { top: 0 } : false),
  });
  routeur.beforeEach((vers) => {
    if (!vers.meta.publique && !lireJeton()) return { name: 'connexion', query: { retour: vers.fullPath } };
  });
  return routeur;
}

export const routeur = creerRouteur();
