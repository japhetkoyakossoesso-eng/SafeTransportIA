# Cas d'utilisation

Mermaid n'a pas de diagramme de cas d'utilisation : les acteurs sont à gauche, les cas
d'utilisation en ovale, avec l'identifiant de la user story du [backlog](../01-cadrage/backlog.md).

```mermaid
flowchart LR
  analyste([Analyste])
  declarant([Agent déclarant])
  responsable([Responsable sécurité])
  admin([Administrateur])
  chercheur([Chercheuse])
  etl([Planificateur ETL])

  subgraph sta [SafeTransport AI]
    direction TB
    uc01([US-01/02 Importer une source])
    uc03([US-03 Consulter le rapport qualité])
    uc04([US-04 Consulter le catalogue des sources])
    uc05([US-05 Chercher et filtrer])
    uc06([US-06 Voir la fiche détail])
    uc07([US-07 Comparer des taux])
    uc09([US-09 Exporter en CSV])
    uc10([US-10 Se connecter])
    uc12([US-12 Tableau de bord Power BI])
    uc13([US-13 Reproduire les statistiques])
    uc20([US-20 Déclarer un signalement])
    uc21([US-21 Qualifier un signalement])
    uc22([US-22 Voir la carte des risques])
    uc23a([US-23 Proposer une recommandation])
    uc23b([US-23 Approuver une mesure])
    uc24([US-24 Évaluer une mesure])
    uc25([US-25 Consulter un score de risque])
    uc26([US-26 Gérer les sources])
    uc30([US-30 Interroger les rapports d'enquête])
  end

  admin --- uc01
  etl --- uc01
  admin --- uc26
  analyste --- uc03
  analyste --- uc05
  analyste --- uc06
  analyste --- uc07
  analyste --- uc09
  analyste --- uc22
  analyste --- uc23a
  analyste --- uc25
  declarant --- uc20
  responsable --- uc21
  responsable --- uc23b
  responsable --- uc24
  responsable --- uc12
  chercheur --- uc04
  chercheur --- uc13
  chercheur --- uc30

  uc05 -. inclut .-> uc10
  uc20 -. inclut .-> uc10
  uc21 -. inclut .-> uc10
  uc23b -. inclut .-> uc10
  uc06 -. étend .-> uc05
  uc09 -. étend .-> uc05
  uc23b -. suit .-> uc23a
```

Notes :

- Tous les cas sauf US-04 et US-12 passent par la connexion (US-10). Ce n'est dessiné que pour
  quelques cas, pour garder le diagramme lisible.
- Un score de risque (US-25) ne déclenche aucune action : il n'y a pas de lien vers US-23b.
