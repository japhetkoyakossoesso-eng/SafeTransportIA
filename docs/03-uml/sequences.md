# Diagrammes de séquence

## 1. Importer une année BAAC (US-01, US-03)

```mermaid
sequenceDiagram
  actor Admin as Administrateur
  participant Back as Back-office (Laravel)
  participant ETL as ETL (FastAPI)
  participant DB as PostgreSQL

  Admin->>Back: lance l'import BAAC 2024
  Back->>ETL: POST /etl/imports {source: onisr_baac, année: 2024}
  ETL->>ETL: télécharge les 4 fichiers, calcule le SHA-256
  ETL->>DB: INSERT import_jobs (status = running, file_sha256)
  alt même fichier déjà importé avec succès
    DB-->>ETL: refus (contrainte d'unicité)
    ETL-->>Back: 409 déjà importé
  else nouveau fichier
    loop chaque ligne
      ETL->>DB: INSERT source_records (ligne brute, record_sha256)
      ETL->>ETL: contrôle qualité, harmonise la gravité
      alt ligne valide
        ETL->>DB: INSERT accidents ... ON CONFLICT (data_source_id, source_ref) DO NOTHING
      else ligne rejetée
        ETL->>DB: UPDATE source_records SET quality_status = rejected, quality_issues
      end
    end
    ETL->>DB: UPDATE import_jobs (status = succeeded, rows_read, rows_rejected…)
    ETL-->>Back: rapport qualité
  end
  Back-->>Admin: affiche le rapport
```

## 2. Chercher des accidents (US-05, US-06)

```mermaid
sequenceDiagram
  actor Analyste
  participant Web as Front (Vue.js)
  participant API as API (Spring Boot)
  participant DB as PostgreSQL

  Analyste->>Web: choisit mode, période, gravité, pays
  Web->>API: GET /api/v1/accidents?mode=road&from=2024-01-01&page=0 (jeton)
  API->>API: vérifie le jeton et le rôle
  alt rôle insuffisant
    API-->>Web: 403
  else autorisé
    API->>DB: SELECT ... WHERE validation_status = 'validated' AND NOT is_simulated
    DB-->>API: lignes + total
    API-->>Web: page de résultats
    Web-->>Analyste: liste, étiquettes « simulé » ou « non vérifié » si demandées
  end
  Analyste->>Web: ouvre un accident
  Web->>API: GET /api/v1/accidents/{public_id}
  API->>DB: accident, lieu, facteurs, source
  API-->>Web: fiche détail avec source et niveau de confiance
```

## 3. Déclarer puis qualifier un signalement (US-20, US-21)

```mermaid
sequenceDiagram
  actor Declarant as Agent déclarant
  actor Resp as Responsable sécurité
  participant Web as Front (Vue.js)
  participant API as API (Spring Boot)
  participant DB as PostgreSQL

  Declarant->>Web: remplit le formulaire (date, mode, description)
  Web->>API: POST /api/v1/reports
  API->>DB: INSERT reports (validation_status = unverified)
  API->>DB: INSERT sensitive.report_contacts
  API-->>Web: 201, signalement « non vérifié »

  Resp->>Web: ouvre la file de revue
  Web->>API: GET /api/v1/reports?status=unverified
  Resp->>Web: qualifie en incident
  Web->>API: POST /api/v1/reports/{id}/qualify {kind: incident}
  API->>DB: SET LOCAL app.user_id = responsable
  API->>DB: INSERT incidents
  API->>DB: UPDATE reports SET validation_status = validated, reviewed_by, incident_id
  Note over DB: le trigger écrit l'avant et l'après dans audit_logs
  API-->>Web: incident créé
```

## 4. Proposer et approuver une recommandation (US-23)

```mermaid
sequenceDiagram
  actor Analyste
  actor Resp as Responsable sécurité
  participant API as API (Spring Boot)
  participant DB as PostgreSQL

  Analyste->>API: POST /api/v1/actions {kind: recommendation, accident_id}
  API->>DB: INSERT corrective_actions (status = proposed)
  Resp->>API: POST /api/v1/actions/{id}/approve
  API->>DB: UPDATE corrective_actions SET kind = measure, status = approved, approved_by, approved_at
  alt approved_by manquant
    DB-->>API: refus (contrainte CHECK)
    API-->>Resp: 422
  else
    DB-->>API: OK
    API-->>Resp: mesure approuvée
  end
```

## 5. Poser une question sur les rapports d'enquête (US-30)

```mermaid
sequenceDiagram
  actor Chercheuse
  participant Web as Front (Vue.js)
  participant RAG as RAG (FastAPI)
  participant DB as PostgreSQL
  participant LLM

  Chercheuse->>Web: « Quels facteurs dans les incursions de piste ? »
  Web->>RAG: POST /rag/ask
  RAG->>DB: recherche hybride : document_chunks (tsvector + vector)
  DB-->>RAG: passages et pages
  alt passages trop faibles
    RAG->>DB: INSERT rag_queries (abstained = true, abstention_reason)
    RAG-->>Web: « pas assez d'éléments dans les rapports »
  else
    RAG->>LLM: question + passages
    LLM-->>RAG: réponse avec citations
    RAG->>DB: INSERT rag_queries, rag_query_chunks (citations, coût, latence)
    RAG-->>Web: réponse + document et page de chaque citation
  end
```
