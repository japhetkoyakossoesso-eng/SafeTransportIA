# Phase 09 : interface web (partie MVP)

Le code est dans `web/` (Vue 3, Vite, Vue Router, Chart.js). L'interface ne parle qu'à l'API Java.

## Lancer

Avec Docker, tout est servi sur http://localhost:5173 :

```bash
docker compose up -d --build api web
```

Pour travailler sur l'interface avec le rechargement automatique (base et API démarrées) :

```bash
cd web
npm install
npm run dev
```

Vite renvoie `/api` vers l'API sur le port 8080.

## Écrans

- **Connexion** : comptes de démonstration `analyste.demo`, `resp.securite.demo`, `admin.demo` (mot de passe `demo`). Le jeton reste dans le navigateur 8 heures ; s'il expire, on revient à la connexion.
- **Recherche** : filtres par mode, période, pays, source et gravité ; cases pour inclure les accidents non vérifiés et simulés. Les filtres sont dans l'adresse de la page, donc une recherche se partage par simple copie du lien.
- **Graphique annuel** : nombre d'accidents et de tués par an, avec les mêmes filtres que la liste. La source est écrite sous le graphique et dans l'image téléchargée. Ce sont des nombres bruts, pas des taux.
- **Liste** : 50 lignes par page, export CSV avec les mêmes filtres. Sur téléphone, chaque ligne devient une petite carte.
- **Fiche détail** : date, heure (UTC), lieu et sa précision, gravité harmonisée et libellé d'origine, victimes, source avec sa licence et sa référence, statut, facteurs marqués « fait établi », « probable » ou « hypothèse ».

Les étiquettes « Simulé » et « Non vérifié » sont visibles dans la liste et sur la fiche.

## Tests

```bash
cd web
npm test
```

Les tests simulent l'API : connexion, redirection sans jeton ou avec un jeton expiré, filtres envoyés à la liste et au graphique, étiquettes, fiche détail.
