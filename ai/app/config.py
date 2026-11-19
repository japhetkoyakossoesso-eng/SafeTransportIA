from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=("../.env", ".env"), extra="ignore")

    db_host: str = "localhost"
    db_port: int = 5432
    postgres_db: str = "safetransport"
    ai_db_user: str = "app_ai"
    ai_db_password: str = "change-me-ai"

    @property
    def database_url(self):
        return f"postgresql://{self.ai_db_user}:{self.ai_db_password}@{self.db_host}:{self.db_port}/{self.postgres_db}"


settings = Settings()
