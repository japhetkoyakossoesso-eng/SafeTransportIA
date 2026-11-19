import hashlib
import json
from pathlib import Path

import psycopg
from psycopg.types.json import Jsonb

from etl.baac import SOURCE, VERSION
from etl.baac.lecture import lire_annee
from etl.baac.transformation import transformer


def empreinte_lot(chemins):
    """Empreinte des 4 fichiers ensemble : sert à repérer un lot déjà importé."""
    h = hashlib.sha256()
    for nom in sorted(chemins):
        h.update(hashlib.sha256(Path(chemins[nom]).read_bytes()).digest())
    return h.hexdigest()


def importer(dossier, database_url, valide_par=None):
    chemins, groupes, doublons = lire_annee(dossier)
    sha_lot = empreinte_lot(chemins)
    noms = ", ".join(p.name for p in chemins.values())

    with psycopg.connect(database_url) as conn:
        conn.execute("SET search_path = core, public")
        conn.execute("SELECT set_config('app.actor_type', 'service', false)")
        source_id = conn.execute("SELECT id FROM data_sources WHERE code = %s", (SOURCE,)).fetchone()[0]

        deja = conn.execute(
            """SELECT id FROM import_jobs
               WHERE data_source_id = %s AND file_sha256 = %s AND status IN ('succeeded', 'partial')""",
            (source_id, sha_lot),
        ).fetchone()
        if deja:
            return {"statut": "deja_importe", "import_job_id": deja[0]}

        job_id = conn.execute(
            """INSERT INTO import_jobs (data_source_id, status, file_name, file_sha256, pipeline_name,
                                        pipeline_version, started_at)
               VALUES (%s, 'running', %s, %s, 'etl.onisr_baac', %s, now()) RETURNING id""",
            (source_id, noms, sha_lot, VERSION),
        ).fetchone()[0]
        conn.commit()

        rapport = {"lus": len(groupes) + len(doublons), "inseres": 0, "rejetes": 0,
                   "doublons": len(doublons), "avertissements": 0, "motifs": {}}
        try:
            for num_acc, groupe in groupes.items():
                ligne = transformer(num_acc, groupe)
                charger_ligne(conn, source_id, job_id, ligne, rapport, valide_par)

            statut = "succeeded" if rapport["rejetes"] == 0 else "partial"
            conn.execute(
                """UPDATE import_jobs
                   SET status = %s, finished_at = now(), rows_read = %s, rows_inserted = %s,
                       rows_rejected = %s, rows_duplicate = %s, error_summary = %s
                   WHERE id = %s""",
                (statut, rapport["lus"], rapport["inseres"], rapport["rejetes"], rapport["doublons"],
                 Jsonb({"motifs": rapport["motifs"], "doublons_dans_le_fichier": doublons[:100]}), job_id),
            )
            conn.commit()
        except Exception as erreur:
            conn.rollback()
            conn.execute(
                """UPDATE import_jobs SET status = 'failed', finished_at = now(), error_summary = %s
                   WHERE id = %s""",
                (Jsonb({"erreur": str(erreur)}), job_id),
            )
            conn.commit()
            raise

    rapport.update(statut=statut, import_job_id=job_id)
    return rapport


def charger_ligne(conn, source_id, job_id, ligne, rapport, valide_par):
    for p in ligne["problemes"]:
        rapport["motifs"][p["regle"]] = rapport["motifs"].get(p["regle"], 0) + 1

    record_id = conn.execute(
        """INSERT INTO source_records (data_source_id, import_job_id, external_id, record_sha256, payload,
                                       quality_status, quality_issues)
           VALUES (%s, %s, %s, %s, %s, %s, %s)
           ON CONFLICT (data_source_id, external_id, record_sha256)
           DO UPDATE SET import_job_id = EXCLUDED.import_job_id
           RETURNING id""",
        (source_id, job_id, ligne["num_acc"], ligne["sha"], Jsonb(ligne["payload"]), ligne["qualite"],
         Jsonb(ligne["problemes"]) if ligne["problemes"] else None),
    ).fetchone()[0]

    if ligne["qualite"] == "rejected":
        rapport["rejetes"] += 1
        return
    if ligne["qualite"] == "warning":
        rapport["avertissements"] += 1

    existe = conn.execute(
        "SELECT 1 FROM accidents WHERE data_source_id = %s AND source_ref = %s", (source_id, ligne["num_acc"])
    ).fetchone()
    if existe:
        rapport["doublons"] += 1
        return

    location_id = conn.execute(
        """INSERT INTO locations (geom, precision, country_code, admin2, insee_code)
           VALUES (CASE WHEN %(lat)s::float8 IS NULL THEN NULL
                        ELSE ST_SetSRID(ST_MakePoint(%(lon)s::float8, %(lat)s::float8), 4326)::geography END,
                   %(precision)s, 'FR', %(dep)s, %(com)s)
           RETURNING id""",
        ligne,
    ).fetchone()[0]

    conn.execute(
        """INSERT INTO accidents (transport_mode_id, occurred_at, occurred_date, location_id, category,
                                 severity, severity_source_label, fatalities, serious_injuries,
                                 minor_injuries, data_source_id, source_record_id, source_ref, confidence,
                                 validation_status, validated_by, validated_at)
           VALUES ((SELECT id FROM transport_modes WHERE code = 'road'), %s, %s, %s, %s, %s, %s, %s, %s, %s,
                   %s, %s, %s, 'high', %s, %s, CASE WHEN %s::bigint IS NULL THEN NULL ELSE now() END)""",
        (ligne["occurred_at"], ligne["occurred_date"], location_id, ligne["category"], ligne["severity"],
         ligne["severity_label"], ligne["fatalities"], ligne["serious_injuries"], ligne["minor_injuries"],
         source_id, record_id, ligne["num_acc"],
         "validated" if valide_par else "unverified", valide_par, valide_par),
    )
    rapport["inseres"] += 1


def rapport_texte(rapport):
    if rapport["statut"] == "deja_importe":
        return f"Ce lot a déjà été importé (import n°{rapport['import_job_id']}). Rien à faire."
    lignes = [
        f"Import n°{rapport['import_job_id']} : {rapport['statut']}",
        f"  accidents lus        : {rapport['lus']}",
        f"  insérés              : {rapport['inseres']}",
        f"  avec avertissement   : {rapport['avertissements']}",
        f"  rejetés              : {rapport['rejetes']}",
        f"  doublons             : {rapport['doublons']}",
    ]
    for regle, nombre in sorted(rapport["motifs"].items()):
        lignes.append(f"    {regle} : {nombre}")
    return "\n".join(lignes)


def en_json(rapport):
    return json.dumps(rapport, ensure_ascii=False, indent=2)
