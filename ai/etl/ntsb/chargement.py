import hashlib
from pathlib import Path

import psycopg
from psycopg.types.json import Jsonb

from etl.ntsb import SOURCE, VERSION
from etl.ntsb.lecture import lire_dossier
from etl.ntsb.transformation import lire_date, transformer


def empreinte_lot(chemins, depuis, jusqua):
    """Les fichiers et la période choisie : importer 2022 puis 2023 depuis le même fichier fait deux lots."""
    h = hashlib.sha256()
    for nom in sorted(chemins):
        h.update(hashlib.sha256(Path(chemins[nom]).read_bytes()).digest())
    h.update(f"{depuis}|{jusqua}".encode())
    return h.hexdigest()


def dans_la_periode(groupe, depuis, jusqua):
    if depuis is None and jusqua is None:
        return True
    try:
        jour = lire_date(groupe["event"]["ev_date"])
    except ValueError:
        return True  # sera rejeté et compté
    return (depuis is None or jour >= depuis) and (jusqua is None or jour <= jusqua)


def importer(dossier, database_url, depuis=None, jusqua=None, valide_par=None):
    chemins, groupes, doublons = lire_dossier(dossier)
    groupes = {k: g for k, g in groupes.items() if dans_la_periode(g, depuis, jusqua)}
    doublons = [d for d in doublons if d in groupes]
    sha_lot = empreinte_lot(chemins, depuis, jusqua)
    noms = ", ".join(p.name for p in chemins.values())
    if depuis or jusqua:
        noms += f" (du {depuis or '…'} au {jusqua or '…'})"

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
               VALUES (%s, 'running', %s, %s, 'etl.ntsb_avall', %s, now()) RETURNING id""",
            (source_id, noms, sha_lot, VERSION),
        ).fetchone()[0]
        conn.commit()

        rapport = {"lus": len(groupes) + len(doublons), "accidents": 0, "incidents": 0, "rejetes": 0,
                   "doublons": len(doublons), "avertissements": 0, "motifs": {}}
        try:
            for ev_id, groupe in groupes.items():
                charger_ligne(conn, source_id, job_id, transformer(ev_id, groupe), rapport, valide_par)

            statut = "succeeded" if rapport["rejetes"] == 0 else "partial"
            conn.execute(
                """UPDATE import_jobs
                   SET status = %s, finished_at = now(), rows_read = %s, rows_inserted = %s,
                       rows_rejected = %s, rows_duplicate = %s, error_summary = %s
                   WHERE id = %s""",
                (statut, rapport["lus"], rapport["accidents"] + rapport["incidents"], rapport["rejetes"],
                 rapport["doublons"],
                 Jsonb({"motifs": rapport["motifs"], "accidents": rapport["accidents"],
                        "incidents": rapport["incidents"], "doublons_dans_le_fichier": doublons[:100]}),
                 job_id),
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
        (source_id, job_id, ligne["ev_id"], ligne["sha"], Jsonb(ligne["payload"]), ligne["qualite"],
         Jsonb(ligne["problemes"]) if ligne["problemes"] else None),
    ).fetchone()[0]

    if ligne["qualite"] == "rejected":
        rapport["rejetes"] += 1
        return
    if ligne["qualite"] == "warning":
        rapport["avertissements"] += 1

    existe = conn.execute(
        """SELECT 1 FROM accidents WHERE data_source_id = %(s)s AND source_ref = %(r)s
           UNION ALL SELECT 1 FROM incidents WHERE data_source_id = %(s)s AND source_ref = %(r)s""",
        {"s": source_id, "r": ligne["ev_id"]},
    ).fetchone()
    if existe:
        rapport["doublons"] += 1
        return

    location_id = conn.execute(
        """INSERT INTO locations (geom, precision, country_code, admin1, municipality, site_code, site_name)
           VALUES (CASE WHEN %(lat)s::float8 IS NULL THEN NULL
                        ELSE ST_SetSRID(ST_MakePoint(%(lon)s::float8, %(lat)s::float8), 4326)::geography END,
                   %(precision)s, %(pays)s, %(etat)s, %(ville)s, %(aeroport_code)s, %(aeroport_nom)s)
           RETURNING id""",
        ligne,
    ).fetchone()[0]

    commun = {**ligne, "location_id": location_id, "source_id": source_id, "record_id": record_id,
              "statut": "validated" if valide_par else "unverified", "valide_par": valide_par}
    if ligne["genre"] == "accident":
        conn.execute(
            """INSERT INTO accidents (transport_mode_id, occurred_at, occurred_date, location_id, category,
                                     severity, severity_source_label, fatalities, serious_injuries,
                                     minor_injuries, data_source_id, source_record_id, source_ref, confidence,
                                     validation_status, validated_by, validated_at)
               VALUES ((SELECT id FROM transport_modes WHERE code = 'air'), %(occurred_at)s,
                       %(occurred_date)s, %(location_id)s, %(category)s, %(severity)s, %(severity_label)s,
                       %(fatalities)s, %(serious_injuries)s, %(minor_injuries)s, %(source_id)s,
                       %(record_id)s, %(ev_id)s, 'high', %(statut)s, %(valide_par)s,
                       CASE WHEN %(valide_par)s::bigint IS NULL THEN NULL ELSE now() END)""",
            commun,
        )
        rapport["accidents"] += 1
    else:
        conn.execute(
            """INSERT INTO incidents (transport_mode_id, incident_class, occurred_at, occurred_date,
                                     location_id, category, minor_injuries, data_source_id, source_record_id,
                                     source_ref, confidence, validation_status, validated_by, validated_at)
               VALUES ((SELECT id FROM transport_modes WHERE code = 'air'), 'incident', %(occurred_at)s,
                       %(occurred_date)s, %(location_id)s, %(category)s, %(minor_injuries)s, %(source_id)s,
                       %(record_id)s, %(ev_id)s, 'high', %(statut)s, %(valide_par)s,
                       CASE WHEN %(valide_par)s::bigint IS NULL THEN NULL ELSE now() END)""",
            commun,
        )
        rapport["incidents"] += 1


def rapport_texte(rapport):
    if rapport["statut"] == "deja_importe":
        return f"Ce lot a déjà été importé (import n°{rapport['import_job_id']}). Rien à faire."
    lignes = [
        f"Import n°{rapport['import_job_id']} : {rapport['statut']}",
        f"  événements lus       : {rapport['lus']}",
        f"  accidents insérés    : {rapport['accidents']}",
        f"  incidents insérés    : {rapport['incidents']}",
        f"  avec avertissement   : {rapport['avertissements']}",
        f"  rejetés              : {rapport['rejetes']}",
        f"  doublons             : {rapport['doublons']}",
    ]
    for regle, nombre in sorted(rapport["motifs"].items()):
        lignes.append(f"    {regle} : {nombre}")
    return "\n".join(lignes)
