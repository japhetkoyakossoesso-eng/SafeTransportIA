# Phase 01 : cadrage

## Objectif

SafeTransport AI aide les équipes sécurité à comprendre les accidents et incidents de transport :
rassembler les données au même endroit, savoir d'où vient chaque chiffre, comparer des taux qui ont
du sens, voir où sont les risques, interroger les rapports d'enquête et suivre les mesures prises.

## Ce que le MVP doit permettre (fin janvier 2027)

Un analyste peut chercher, filtrer et comparer des accidents routiers (France, ONISR BAAC) et aériens
(NTSB) validés, avec des taux rapportés à l'exposition, depuis l'application web et Power BI.

Dans le MVP :

- import d'une année BAAC et d'un extrait NTSB, avec rapport qualité ;
- recherche, filtres, fiche détail, graphiques dans l'application Vue.js ;
- API Java avec rôles et journal d'audit ;
- taux pour 10⁸ unités d'exposition, avec intervalles de confiance ;
- tableau de bord Power BI branché sur le schéma `bi` ;
- tests automatiques à chaque push.

Après le MVP : signalements, carte, recommandations, ML (jalon 2), puis NLP, RAG, agents,
ferroviaire et maritime (jalon 3). Le détail est dans le [backlog](backlog.md).

## Vocabulaire

Ces six notions ne doivent jamais être mélangées, ni dans la base, ni dans l'interface.

| Notion | Définition | Où dans la base |
|---|---|---|
| Accident | événement avec victimes ou dégâts, au sens de la définition officielle du mode (ONISR, OACI annexe 13) | `core.accidents` |
| Incident | événement sans accident : incident grave, incident, quasi-accident | `core.incidents` |
| Signalement non vérifié | déclaration saisie par un agent, pas encore revue | `core.reports`, statut `unverified` |
| Hypothèse | cause possible, pas prouvée | `accident_factors.assertion_level = 'hypothesis'` |
| Recommandation | mesure proposée, pas encore décidée | `corrective_actions.kind = 'recommendation'` |
| Donnée simulée | donnée inventée pour les tests et la démo | colonne `is_simulated` |

## Règles qui s'appliquent partout

1. Chaque chiffre affiché renvoie à sa source (`data_source_id`, ligne brute dans `source_records`).
2. Par défaut on n'affiche que les données validées et réelles ; le reste est visible mais étiqueté.
3. On ne compare deux modes ou deux pays qu'avec la même définition et un dénominateur d'exposition
   (vols, véhicules-km, trafic). Sans dénominateur, le taux est « non calculable ».
4. Une prédiction est une aide à l'analyse, affichée avec son incertitude. Elle ne déclenche jamais
   d'action automatique.
5. Une mesure ne passe « approuvée » qu'avec un approbateur humain.
6. Les données personnelles restent dans le schéma `sensitive`, lisible seulement par l'API.

## Définition de « terminé » pour une user story

- les critères d'acceptation de la story sont couverts par des tests qui passent en CI ;
- le code est relu (pull request) et fusionné dans `main` ;
- la documentation utile est à jour (README du service, OpenAPI pour l'API) ;
- aucune donnée simulée ou non vérifiée n'apparaît sans son étiquette.

## Fichiers

- [personas.md](personas.md) : qui utilise l'application et pour quoi faire
- [backlog.md](backlog.md) : user stories et critères d'acceptation
