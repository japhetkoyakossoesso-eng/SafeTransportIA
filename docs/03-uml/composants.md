# Diagramme de composants

```mermaid
flowchart TB
  subgraph clients [Utilisateurs]
    nav[Navigateur]
    pbi[Power BI]
    r[R / notebooks]
  end

  subgraph services [Services]
    web[web<br/>Vue.js + nginx]
    api[api<br/>Spring Boot]
    ai[ai<br/>FastAPI : ETL, ML, RAG]
    admin[admin<br/>Laravel]
    notif[notifications<br/>Node.js]
  end

  subgraph data [Données]
    db[(PostgreSQL 16<br/>PostGIS + pgvector)]
    fly[Flyway<br/>db/migrations]
  end

  ext[Sources ouvertes<br/>ONISR, NTSB, SDES, FAA]
  llm[Fournisseur LLM]

  nav -->|HTTPS| web
  web -->|/api REST| api
  web -->|/ai REST| ai
  nav -->|HTTPS| admin
  admin -->|REST| api
  admin -->|lance les imports| ai
  api -->|app_api : core + sensitive| db
  ai -->|app_ai : écriture des faits, chunks, prédictions| db
  admin -->|app_admin : schéma admin| db
  api -.->|événements| notif
  ai -->|téléchargement| ext
  ai -->|questions + passages| llm
  pbi -->|app_bi : schéma bi| db
  r -->|app_bi : schéma bi| db
  fly -->|propriétaire du schéma| db
```

| Composant | Compte base | Ce qu'il peut faire |
|---|---|---|
| api | `app_api` (rôle `st_api`) | lire et écrire `core`, seul à lire `sensitive` |
| ai | `app_ai` (`st_etl` + `st_ml`) | écrire imports, faits, documents, prédictions, requêtes RAG |
| admin | `app_admin` | ses propres tables dans le schéma `admin` ; les données métier passent par l'API |
| Power BI, R | `app_bi` (`st_bi_reader`) | lire le schéma `bi` uniquement |
| agent IA (jalon 3) | rôle `st_agent_readonly` | lire `core` et `bi`, sans `audit_logs` ni `users` |
