from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Configuration lue dans les variables d'environnement (voir .env.example)."""

    model_config = SettingsConfigDict(env_file=("../.env", ".env"), extra="ignore")

    db_host: str = "localhost"
    db_port: int = 5432
    postgres_db: str = "safetransport"
    ai_db_user: str = "app_ai"
    ai_db_password: str = "change-me-ai"

    @property
    def database_url(self) -> str:
        return (
            f"postgresql://{self.ai_db_user}:{self.ai_db_password}"
            f"@{self.db_host}:{self.db_port}/{self.postgres_db}"
        )


settings = Settings()
