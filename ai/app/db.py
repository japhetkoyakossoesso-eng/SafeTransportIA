import psycopg

from app.config import settings


def database_version() -> str:
    """Renvoie les versions PostgreSQL / PostGIS / pgvector, ou lève une exception."""
    with psycopg.connect(settings.database_url, connect_timeout=3) as conn:
        row = conn.execute(
            "SELECT current_setting('server_version'), postgis_lib_version(), "
            "(SELECT extversion FROM pg_extension WHERE extname = 'vector')"
        ).fetchone()
    return f"postgres {row[0]}, postgis {row[1]}, pgvector {row[2]}"
