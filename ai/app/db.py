import psycopg

from app.config import settings


def database_version():
    with psycopg.connect(settings.database_url, connect_timeout=3) as conn:
        row = conn.execute(
            "SELECT postgis_lib_version(), (SELECT extversion FROM pg_extension WHERE extname = 'vector')"
        ).fetchone()
    return f"postgis {row[0]}, pgvector {row[1]}"
