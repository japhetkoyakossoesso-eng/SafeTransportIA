# Backlog

Chaque story a un identifiant, le jalon où elle doit être livrée, le service concerné et des
critères d'acceptation qu'on peut tester. Une story est terminée quand ses critères sont couverts
par des tests (voir la définition de « terminé » dans le [README](README.md)).

Jalons : **J1** = MVP (fin janvier 2027), **J2** = intermédiaire (février), **J3** = avancé (mars).

## Vue d'ensemble

| ID | Story | Jalon | Service |
|---|---|---|---|
| US-01 | Importer une année BAAC | J1 | ai (ETL) |
| US-02 | Importer un extrait NTSB | J1 | ai (ETL) |
| US-03 | Voir le rapport qualité d'un import | J1 | ai, api, web |
| US-04 | Consulter le catalogue des sources | J1 | db, api |
| US-05 | Chercher et filtrer les accidents | J1 | api, web |
| US-06 | Voir la fiche détail d'un accident | J1 | api, web |
| US-07 | Comparer des taux rapportés à l'exposition | J1 | api, web, analyses |
| US-08 | Voir l'évolution annuelle en graphique | J1 | web |
| US-09 | Exporter les résultats en CSV | J1 | api |
| US-10 | Se connecter avec un rôle | J1 | api |
| US-11 | Tracer chaque modification | J1 | db, api |
| US-12 | Consulter le tableau de bord Power BI | J1 | bi |
| US-13 | Reproduire les statistiques | J1 | analyses |
| US-20 | Déclarer un signalement | J2 | web, api |
| US-21 | Revoir et qualifier un signalement | J2 | admin, api |
| US-22 | Voir la carte des risques | J2 | web, api |
| US-23 | Proposer et approuver une recommandation | J2 | web, api |
| US-24 | Évaluer l'efficacité d'une mesure | J2 | api, analyses |
| US-25 | Consulter un score de risque | J2 | ai (ML), web |
| US-26 | Gérer les sources et les imports manuels | J2 | admin |
| US-27 | Saisir depuis Power Apps | J2 | Power Apps |
| US-30 | Interroger les rapports d'enquête | J3 | ai (RAG), web |
| US-31 | Extraire les informations des rapports PDF | J3 | ai (NLP) |
| US-32 | Utiliser un agent IA en lecture seule | J3 | ai |
| US-33 | Être prévenu des mesures en retard | J3 | notifications |
| US-34 | Ajouter le ferroviaire et le maritime | J3 | ai, db |
| US-35 | Restaurer une sauvegarde | J3 | db |

## Jalon 1 : MVP

### US-01 Importer une année BAAC

En tant que Thomas (administrateur), je veux importer les fichiers BAAC d'une année pour avoir les
accidents routiers dans la base.

- Un import crée une ligne dans `import_jobs` qui finit en `succeeded` ou `partial`.
- Chaque ligne lue est gardée telle quelle dans `source_records`, avec son empreinte SHA-256.
- Relancer le même fichier ne crée aucun nouvel accident.
- Une ligne rejetée est comptée et son motif est enregistré.
- Les accidents importés ont le mode `road`, la source `onisr_baac` et `is_simulated = false`.

### US-02 Importer un extrait NTSB

En tant que Thomas, je veux importer les accidents aériens du NTSB.

- Les événements « accident » vont dans `accidents`, les « incident » dans `incidents`.
- La gravité est harmonisée (`severity`) et le libellé d'origine est conservé.
- Relancer le même fichier ne crée aucun doublon.

### US-03 Voir le rapport qualité d'un import

En tant que Claire (analyste), je veux savoir ce qu'un import a donné pour juger la fiabilité des
données.

- Le rapport affiche : lignes lues, valides, avec avertissement, rejetées, doublons.
- La somme des catégories est égale au nombre de lignes lues.
- On peut voir le motif de chaque rejet.

### US-04 Consulter le catalogue des sources

En tant qu'Amina (chercheuse), je veux connaître chaque source pour savoir comment l'utiliser.

- Chaque source a une fiche : organisme, URL, licence, format, couverture, biais connus.
- `GET /api/v1/sources` renvoie la liste des fiches.
- Aucun accident ou incident n'existe sans source (contrainte en base, déjà testée).

### US-05 Chercher et filtrer les accidents

En tant que Claire, je veux filtrer les accidents par mode, période, gravité et pays.

- Les filtres se combinent.
- Les résultats sont paginés.
- Par défaut, seuls les accidents validés et réels sont affichés ; une case permet d'inclure les
  non vérifiés et les simulés, qui sont alors étiquetés.
- Une recherche sur une année BAAC répond en moins de 2 secondes.
- L'écran est utilisable sur téléphone.

### US-06 Voir la fiche détail d'un accident

En tant que Claire, je veux ouvrir un accident pour voir toutes ses informations.

- La fiche montre : date, lieu, gravité harmonisée et libellé d'origine, nombre de victimes, source
  avec lien, niveau de confiance, statut de validation.
- Les facteurs sont affichés avec leur statut : fait établi, probable ou hypothèse.
- Une étiquette visible signale un accident simulé ou non vérifié.

### US-07 Comparer des taux rapportés à l'exposition

En tant que Claire, je veux comparer des taux et non des nombres bruts.

- Le taux est calculé pour 10⁸ unités d'exposition et l'unité est affichée (vols, véhicules-km…).
- Sans mesure d'exposition pour la période, le taux affiche « non calculable ».
- Deux séries avec des unités d'exposition différentes ne sont pas mises sur le même graphique.
- Les données simulées sont exclues du calcul.

### US-08 Voir l'évolution annuelle en graphique

En tant que Claire, je veux un graphique par année pour voir les tendances.

- Le graphique suit les filtres de la recherche.
- La source est écrite sous le graphique.
- Le graphique s'exporte en image.

### US-09 Exporter les résultats en CSV

En tant que Claire, je veux exporter ma recherche pour la retravailler.

- Le CSV contient les mêmes lignes que l'écran (mêmes filtres).
- Chaque ligne a sa source et son statut de validation.
- Aucune donnée du schéma `sensitive` n'est exportée.

### US-10 Se connecter avec un rôle

En tant qu'utilisateur, je veux me connecter et n'accéder qu'à ce que mon rôle permet.

- Sans jeton, l'API répond 401.
- Avec un rôle insuffisant, l'API répond 403 (par exemple un analyste qui modifie un accident).
- Les rôles sont ceux de la table `roles` : admin, analyst, reporter, safety_manager, researcher.

### US-11 Tracer chaque modification

En tant que Sophie (responsable sécurité), je veux savoir qui a modifié quoi et quand.

- Toute modification d'un fait crée une ligne dans `audit_logs` avec l'auteur, la date, l'avant et
  l'après.
- Le journal ne peut pas être modifié ni effacé.

### US-12 Consulter le tableau de bord Power BI

En tant que Sophie, je veux un tableau de bord prêt à présenter.

- Trois pages : par mode, par période et zone, qualité des données.
- Les totaux sont égaux à ceux de l'API sur la même période et les mêmes filtres.
- Power BI se connecte avec le compte `app_bi`, qui ne voit que le schéma `bi`.

### US-13 Reproduire les statistiques

En tant qu'Amina, je veux pouvoir refaire les calculs moi-même.

- Un notebook (R ou Python) relance toute l'analyse depuis la base.
- Les taux ont un intervalle de confiance à 95 %.
- Une note de méthode explique les choix et les biais de chaque source.

## Jalon 2 : intermédiaire

### US-20 Déclarer un signalement

En tant que Karim (agent déclarant), je veux déclarer un événement depuis mon téléphone.

- Seuls la date, le mode et la description sont obligatoires.
- Le signalement est créé avec le statut « non vérifié ».
- Il n'entre dans aucune statistique tant qu'il n'est pas validé.
- Les coordonnées de Karim sont stockées dans le schéma `sensitive`.
- Karim voit le statut de ses propres signalements, pas ceux des autres.

### US-21 Revoir et qualifier un signalement

En tant que Sophie, je veux traiter les signalements en attente.

- Je peux qualifier un signalement en accident ou en incident, ou le rejeter.
- Un rejet demande un motif.
- La décision garde le lien avec le signalement d'origine et le nom de la personne qui a décidé.

### US-22 Voir la carte des risques

En tant que Claire, je veux voir les accidents sur une carte.

- Les points proches sont regroupés.
- Une zone n'est colorée selon son taux que si son dénominateur d'exposition existe.
- La précision du lieu est respectée : un accident localisé à la commune n'est pas placé sur un point
  exact.

### US-23 Proposer et approuver une recommandation

En tant que Claire, je veux proposer une recommandation ; en tant que Sophie, je veux l'approuver.

- Une recommandation proposée n'est pas une mesure.
- Elle ne devient mesure qu'avec un approbateur (contrainte en base, déjà testée).
- Une recommandation suggérée par l'IA est marquée comme telle.

### US-24 Évaluer l'efficacité d'une mesure

En tant que Sophie, je veux savoir si une mesure a marché.

- Une évaluation compare une période avant et une période après, sur le même périmètre.
- La conclusion est l'une de : efficace, partiellement efficace, inefficace, non concluant.
- La méthode et les limites sont écrites dans l'évaluation.

### US-25 Consulter un score de risque

En tant que Claire, je veux un score de risque par zone et période.

- Le score est affiché avec son intervalle et la version du modèle.
- La mention « aide à l'analyse, pas une décision » est toujours visible.
- Le modèle bat une baseline simple sur une période de test postérieure à l'entraînement.
- Aucune action n'est déclenchée automatiquement par un score.

### US-26 Gérer les sources et les imports manuels

En tant que Thomas, je veux gérer les sources et charger un fichier depuis le back-office.

- Je peux créer et modifier une fiche source.
- Je peux charger un fichier CSV, XML ou JSON et suivre son import.
- Le back-office passe par l'API Java pour les données métier.

### US-27 Saisir depuis Power Apps

En tant que Karim, je veux pouvoir déclarer depuis Power Apps si mon organisation l'utilise.

- Le formulaire crée le même signalement que l'application web.
- Si aucune licence n'est disponible, cette story est remplacée par US-20.

## Jalon 3 : avancé

### US-30 Interroger les rapports d'enquête

En tant qu'Amina, je veux poser une question sur les rapports BEA et NTSB.

- Chaque réponse cite ses sources : document et page.
- S'il n'y a pas assez d'éléments, l'outil le dit au lieu d'inventer.
- Chaque question est enregistrée avec sa réponse, ses citations, son coût et son temps de réponse.
- Un jeu de questions de référence mesure la fidélité et le taux d'abstention.

### US-31 Extraire les informations des rapports PDF

En tant qu'Amina, je veux que les rapports soient découpés et indexés automatiquement.

- Les sections, dates et organismes sont extraits.
- La précision est mesurée sur un petit jeu annoté à la main.

### US-32 Utiliser un agent IA en lecture seule

En tant que Claire, je veux un assistant qui cherche et calcule pour moi.

- L'agent utilise le compte `st_agent_readonly` : aucune écriture possible.
- Il ne voit ni les données personnelles ni le journal d'audit.
- Chaque action de l'agent est journalisée.

### US-33 Être prévenu des mesures en retard

En tant que Sophie, je veux être prévenue quand une mesure dépasse son échéance.

- Une notification part le jour du dépassement, une seule fois.
- Elle contient le lien vers la mesure.

### US-34 Ajouter le ferroviaire et le maritime

En tant qu'Amina, je veux étendre les analyses à d'autres modes.

- Les définitions d'accident de chaque mode sont écrites avant tout import.
- Aucune comparaison entre modes n'est affichée sans dénominateur commun.

### US-35 Restaurer une sauvegarde

En tant que Thomas, je veux être sûr de pouvoir restaurer la base.

- Une sauvegarde est faite automatiquement chaque jour.
- Une restauration a été testée et documentée.
