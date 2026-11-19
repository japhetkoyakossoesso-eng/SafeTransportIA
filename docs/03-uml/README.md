# Phase 03 : dossier UML

Les diagrammes sont écrits en [Mermaid](https://mermaid.js.org) : GitHub les affiche directement
et ils se modifient comme du texte.

| Diagramme | Contenu |
|---|---|
| [Cas d'utilisation](cas-utilisation.md) | les 5 acteurs et ce qu'ils font, relié aux user stories |
| [Classes](classes.md) | les 27 tables et leurs relations, généré depuis la base |
| [Séquences](sequences.md) | import BAAC, recherche, signalement, recommandation, question RAG |
| [Composants](composants.md) | les services, la base et leurs échanges |

## Cohérence avec le schéma SQL

Le diagramme de classes n'est pas dessiné à la main : `db/tools/uml_classes.sql` le produit à partir
des tables réelles. Après une nouvelle migration :

```bash
make db-migrate
make uml
```

La CI régénère le fichier et échoue s'il ne correspond plus à la base.

Les autres diagrammes utilisent les noms de tables et de colonnes du schéma (`reports`,
`validation_status`, `corrective_actions.kind`…) pour qu'on puisse passer de l'un à l'autre.
