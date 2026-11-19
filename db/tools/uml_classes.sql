-- Génère docs/03-uml/classes.md depuis la base : le diagramme de classes suit toujours le schéma.
-- Usage : make uml
\set QUIET on
\pset tuples_only on
\pset format unaligned

WITH tables AS (
  SELECT c.oid, n.nspname AS schema, c.relname AS name
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE c.relkind = 'r' AND n.nspname IN ('core', 'sensitive')
),
pk AS (
  SELECT con.conrelid AS oid, unnest(con.conkey) AS attnum
  FROM pg_constraint con WHERE con.contype = 'p'
),
cols AS (
  SELECT t.name, a.attnum,
         '    ' || replace(replace(regexp_replace(format_type(a.atttypid, NULL), '^core\.', ''),
                 'timestamp with time zone', 'timestamptz'), 'character', 'char') || ' ' || a.attname
           || CASE WHEN pk.attnum IS NOT NULL THEN ' PK' ELSE '' END AS line
  FROM tables t
  JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum > 0 AND NOT a.attisdropped
  LEFT JOIN pk ON pk.oid = t.oid AND pk.attnum = a.attnum
),
classes AS (
  SELECT t.name,
         '  class ' || t.name || ' {' || E'\n'
         || CASE WHEN t.schema = 'sensitive' THEN '    <<sensitive>>' || E'\n' ELSE '' END
         || string_agg(c.line, E'\n' ORDER BY c.attnum) || E'\n  }' AS block
  FROM tables t JOIN cols c ON c.name = t.name
  GROUP BY t.name, t.schema
),
fks AS (
  SELECT DISTINCT '  ' || ref.relname || ' "1" <-- "*" ' || src.relname || ' : ' || a.attname AS line
  FROM pg_constraint con
  JOIN pg_class src ON src.oid = con.conrelid
  JOIN pg_class ref ON ref.oid = con.confrelid
  JOIN pg_namespace n ON n.oid = src.relnamespace
  JOIN pg_attribute a ON a.attrelid = con.conrelid AND a.attnum = con.conkey[1]
  WHERE con.contype = 'f' AND n.nspname IN ('core', 'sensitive')
)
SELECT '# Diagramme de classes' || E'\n\n'
  || 'Fichier généré par `db/tools/uml_classes.sql` (commande `make uml`). Ne pas modifier à la main :' || E'\n'
  || 'changer une migration, puis régénérer. La CI vérifie que ce fichier correspond à la base.' || E'\n\n'
  || 'Tables des schémas `core` et `sensitive` (données personnelles, marquées `sensitive`).' || E'\n'
  || 'Une flèche va de la table qui porte la clé étrangère vers la table référencée.' || E'\n\n'
  || '```mermaid' || E'\n' || 'classDiagram' || E'\n'
  || (SELECT string_agg(block, E'\n' ORDER BY name) FROM classes) || E'\n'
  || (SELECT string_agg(line, E'\n' ORDER BY line) FROM fks) || E'\n'
  || '```';
