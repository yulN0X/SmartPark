from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    PROJECT_NAME: str = "Parkir Boss API"
    # No insecure default — must come from .env or the environment (fail-fast).
    SECRET_KEY: str
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7 # 7 days
    # Defaulting to sqlite for easy local development without installing postgres
    DATABASE_URL: str = "sqlite:///./parkirboss.db"

    class Config:
        env_file = ".env"

try:
    settings = Settings()
except Exception as exc:  # missing SECRET_KEY → refuse to start instead of using a weak default
    raise SystemExit(
        "\nFATAL: SECRET_KEY belum diset.\n"
        "Buat file ParkirBoss/parkirboss-api/.env berisi:\n"
        "    SECRET_KEY=<kunci-acak>\n"
        "Generate: python -c \"import secrets; print(secrets.token_urlsafe(64))\"\n"
        f"(detail: {exc})\n"
    )
