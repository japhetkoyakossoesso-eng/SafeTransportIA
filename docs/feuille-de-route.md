# SafeTransport AI : feuille de route

Version du 19 novembre 2026. La version vivante est le document partagé :
https://claude.ai/artifact/8HTCanEuPkQNKmc2kRmBNy

## Principe

On livre d'abord un MVP complet et démontrable sur deux modes (routier France, aérien), puis on ajoute les services un par un. Les 18 phases du cahier des charges V3 sont regroupées en trois jalons, chacun se terminant par une démo.

- **Jalon 1, MVP** : données routières et aériennes, ETL Python, PostgreSQL, API Java, interface Vue.js, statistiques, Power BI, tests.
- **Jalon 2, intermédiaire** : portail PHP, cartographie, signalements, ML évalué, recommandations, Power Apps.
- **Jalon 3, avancé** : NLP, RAG/LLM, agents contrôlés, MLOps, ferroviaire et maritime.

Plan retenu : tout le périmètre du cahier des charges, terminé fin mars 2027. Cela représente environ 650 h (estimation) sur 16 semaines utiles, soit environ 40 h par semaine.

## Avancement

| Phase | État |
|---|---|
| 01 Cadrage | fait ([docs/01-cadrage](01-cadrage/README.md)) |
| 02 Sources | fait ([docs/02-sources](02-sources/README.md)) |
| 03 UML | fait ([docs/03-uml](03-uml/README.md)) |
| 04 Environnement et CI | fait (Docker Compose, CI GitHub Actions) |
| 05 Base de données | fait (migrations Flyway V1 à V4, 29 tests SQL) |
| 06 ETL Python | BAAC fait ([docs/06-etl](06-etl/README.md)), validé sur 2023 ; NTSB à faire |
| 07 API Java | fait ([docs/07-api](07-api/README.md)) |

## Jalon 1 : MVP (23 novembre 2026 → fin janvier 2027)

Le MVP est atteint quand un analyste peut chercher, filtrer et comparer des accidents routiers et aériens validés, avec des taux rapportés à l'exposition, depuis l'application web et Power BI. Les phases sont dans l'ordre où elles se font.

| Phase | Livrable | Critère d'acceptation |
|---|---|---|
| 01 Cadrage | Backlog, personas (analyste, déclarant, responsable sécurité), critères d'acceptation | Chaque user story du MVP a un critère testable |
| 02 Sources | Catalogue des sources : ONISR BAAC (data.gouv.fr), NTSB ; licence, format, dictionnaire, biais | Fiche par source remplie dans `data_sources` |
| 03 UML | Cas d'utilisation, classes, séquences, composants | Dossier UML cohérent avec le schéma SQL |
| 04 Environnement et CI | Monorepo GitHub, Docker Compose (PostGIS + pgvector), conventions, CI qui lance les tests | `docker compose up` démarre la base ; la CI passe sur chaque PR |
| 05 Base de données | Schéma versionné (migrations), schéma BI, rôles, tests SQL | 29/29 tests, migrations Flyway |
| 06 ETL Python | Pipeline ONISR BAAC puis NTSB : extraction, nettoyage, dédoublonnage, rapport qualité | Rejouer deux fois le même import ne crée aucun doublon ; chaque rejet est journalisé |
| 07 API Java | Spring Boot : accidents/incidents (liste, filtres, détail), sources, authentification par rôles, audit | OpenAPI publiée ; tests JUnit sur services et contrôleurs ; accès refusé sans le bon rôle |
| 09 Interface web (partie MVP) | Vue.js : recherche, filtres (mode, période, gravité, pays), fiche détail, graphiques Chart.js | Utilisable sur mobile ; données simulées et non vérifiées clairement étiquetées |
| 10 Statistiques R/Python | Descriptif, taux pour 10⁸ véhicules-km ou vols, intervalles de confiance, analyse des biais | Notebook reproductible + note méthodologique ; chaque chiffre renvoie à sa source |
| 11 Power BI (partie MVP) | Modèle en étoile branché sur le schéma `bi`, mesures DAX, 3 pages (mode, période/zone, qualité des données) | Les totaux Power BI égalent ceux de l'API sur la même période |

Démo de fin de jalon : import d'une année BAAC en direct, recherche dans l'application, tableau de bord Power BI.

## Jalon 2 : intermédiaire (février 2027)

Ce jalon ajoute la saisie et la validation humaine, la carte et un premier modèle prédictif évalué.

| Phase | Livrable | Critère d'acceptation |
|---|---|---|
| 08 Portail PHP | Laravel : sources, imports manuels CSV/XML/JSON, revue des signalements, audit ; appels à l'API Java | Aucun accès direct à la base depuis PHP ; tests PHPUnit |
| 09 Cartographie | Carte Leaflet, regroupements, zones à risque rapportées à l'exposition | Une zone n'est colorée que si son dénominateur d'exposition existe |
| Signalements | Formulaire déclarant (table `reports`), file de revue, qualification en accident ou incident | Un signalement reste « non vérifié » tant qu'un responsable ne l'a pas revu |
| 11 Power Apps | Prototype de saisie + workflow Automate, selon licence disponible | Remplacé par le formulaire Vue.js si pas de licence |
| 12 Machine Learning | Baseline, séparation temporelle, Random Forest/XGBoost, calibration, carte de modèle, API FastAPI | Bat la baseline sur une période de test postérieure à l'entraînement ; score affiché avec son incertitude |
| Recommandations (début de 17) | Catalogue de mesures, plan d'action, validation humaine | Aucune mesure ne passe « approuvée » sans approbateur (déjà imposé par le schéma) |

## Jalon 3 : avancé (mars 2027)

Ce jalon apporte l'IA documentaire et l'extension aux autres modes ; il se réduit si le temps manque, sans toucher au MVP.

| Phase | Livrable | Critère d'acceptation |
|---|---|---|
| 13 NLP documentaire | Extraction PDF (rapports BEA/NTSB), sections, dates, organismes, entités | Jeu de test annoté ; précision mesurée |
| 14 LLM et RAG | Chunking, embeddings, pgvector, recherche hybride, citations avec pages, chat | Benchmark de questions de référence : fidélité, taux d'abstention, coût, latence |
| 15 Deep Learning (optionnel) | Comparaison avec la baseline | Seulement si volume et qualité suffisants |
| 16 Agents contrôlés | Agent en lecture seule (rôle `st_agent_readonly`), outils de recherche et statistiques, journal | Aucune écriture possible côté base (déjà testé) |
| 17 Prévention, MLOps, sécurité | Suivi et évaluation des mesures, MLflow, tests RAG, monitoring, sauvegardes | Restauration d'une sauvegarde testée |
| Ferroviaire, maritime, Node.js | Nouvelles sources, notifications temps réel | Définitions harmonisées documentées avant toute comparaison |
| 18 Déploiement et soutenance | Tests bout en bout, CI/CD, documentation, démo, bilan des limites | Version démontrable, rapport et présentation |

## Données en temps réel (complément)

Les flux temps réel enrichissent la plateforme, mais ne remplacent jamais les données officielles : un événement en direct n'est pas un accident validé. Ils entrent dans les jalons 2 et 3 sans décaler la fin mars.

| Flux | Ce qu'il apporte | Jalon | Usage dans SafeTransport AI |
|---|---|---|---|
| Événements routiers (Bison Futé, format DATEX II, via transport.data.gouv.fr) | Accidents signalés, bouchons, travaux, fermetures | 2 (février) | Signalements non vérifiés affichés sur la carte ; rapprochement possible avec les accidents BAAC après coup |
| Météo-France (API, compte gratuit à créer) | Observations et vigilances | 2 (février) | Remplit `weather_conditions` ; variable de contexte pour les statistiques et le ML |
| OpenSky Network | Positions des vols en direct | 3 (mars) | Couche de trafic aérien sur la carte ; base d'un dénominateur d'exposition (vols) |
| AIS (positions des navires, par ex. un flux WebSocket gratuit) | Trafic maritime | 3 (mars) | Couche maritime ; contexte pour le mode maritime |
| Notifications Node.js | Diffusion en direct des nouveaux événements | 3 (mars) | Alerte un analyste quand un événement tombe dans une zone à risque ; aucune logique métier dans Node.js |

Règles :

- Chaque flux est déclaré comme source (`data_sources`, type `api`) avec sa licence, et chaque événement reçu garde sa ligne brute dans `source_records`.
- Les événements en direct sont stockés comme contexte ou signalements « non vérifiés », séparés des accidents validés. Ils n'entrent pas dans les taux officiels.
- Une nouvelle table `live_events` (événement, position, horodatage, source, expiration) sera ajoutée au schéma ; les positions OpenSky et AIS sont agrégées ou purgées régulièrement pour limiter le volume.
- Les conditions d'utilisation de chaque flux (quotas, usage non commercial, attribution) sont à vérifier en phase 02 avant le premier branchement.

## Calendrier

Le diagramme de Gantt est dans le document partagé. Point de contrôle fin janvier : si le MVP n'est pas livré, le rythme de 40 h ne tient pas et on passe à une des options de repli ci-dessous.

## Options de repli si le rythme ne tient pas

Le plan retenu garde tout le périmètre. Les options ci-dessous ne servent que si le point de contrôle de fin janvier montre un retard. À partir du 23 novembre 2026, en comptant deux semaines de pause pour les fêtes, il reste environ 12 semaines utiles jusqu'à fin février et 17 jusqu'à fin mars.

| Option | Périmètre livré | Volume estimé | Rythme nécessaire |
|---|---|---|---|
| Fin février 2027 | MVP seul (jalon 1), simplifié : une année BAAC + un extrait NTSB, API Java, Vue.js, statistiques, Power BI, tests, démo et rapport | environ 300 h | environ 25 h par semaine |
| Fin mars 2027 (recommandé) | MVP + version intermédiaire allégée : carte Leaflet, signalements et recommandations avec validation humaine, modèle ML de base évalué (FastAPI) | environ 450 h | environ 26 h par semaine |
| Fin mars 2027, avec IA documentaire | Option précédente + petit RAG sur 10 à 20 rapports BEA/NTSB avec citations | environ 520 h | environ 30 h par semaine |
| Fin septembre 2027 | Cahier des charges complet (plan d'origine ci-dessus) | environ 650 h | environ 15 h par semaine |

En cas de repli, ce qu'on retirerait ou simplifierait :

- **Retiré** : Node.js (notifications), Power Apps (formulaire Vue.js à la place), ferroviaire et maritime, Deep Learning, agents IA, MLflow et monitoring.
- **Simplifié** : portail PHP réduit à un écran d'import et de validation (ou reporté, s'il n'est pas exigé pour la licence), UML limité aux 4 diagrammes utiles, CI qui lance seulement les tests.
- **Gardé tel quel** : la base de données (déjà faite), la traçabilité des sources, les tests et la distinction entre données vérifiées, hypothèses et données simulées. C'est ce qui donne sa valeur au projet.

Les volumes sont des estimations pour une personne qui apprend une partie des technologies en chemin ; Spring Boot et Vue.js sont les postes les plus incertains. Les parties retirées restent dans le plan d'origine comme perspectives pour le rapport.

## Risques et garde-fous

| Risque | Garde-fou |
|---|---|
| Trop de technologies pour une seule personne (Java, Python, PHP, Node, Vue, R, Power Platform) | Le MVP se limite à SQL, Python, Java, Vue.js et Power BI ; PHP et Node arrivent après |
| Formats et définitions qui changent selon l'année ou la source | Ligne brute conservée dans `source_records`, libellé source gardé à côté de la gravité harmonisée, biais notés par source |
| Comparaisons trompeuses entre modes ou pays | Taux calculés seulement quand une mesure d'exposition existe (`exposure_measures`) |
| Prédiction prise pour une décision | Score toujours affiché avec intervalle et mention « aide à l'analyse » ; aucune action automatique |
| Réponses RAG non fondées | Citation obligatoire, abstention tracée, benchmark avant mise en avant |
| Licences Power Apps indisponibles | Formulaire Vue.js comme solution de repli |
| Données personnelles | Schéma `sensitive` séparé, pas d'immatriculation routière, purge des contacts déclarants |

## Questions ouvertes

- Date de soutenance et nombre d'heures par semaine disponibles (le calendrier suppose environ 40 h).
- Accès à une licence Power Apps via l'université ?
