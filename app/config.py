"""アプリ設定。環境変数 / .env から読み込む。"""

from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    gemini_api_key: str = ""
    gemini_model: str = "gemini-3.5-flash"

    temperature: float = 1.0
    max_output_tokens: int = 2048

    request_timeout: float = 60.0
    max_retries: int = 2
    cache_ttl: int = 0

    # このゲートウェイを叩くのに必要なキー（カンマ区切り）。空なら認証なし。
    # GEMINI_API_KEY（上流に出すキー）とは別物。
    api_keys: str = ""

    cors_origins: str = "*"
    log_level: str = "INFO"

    @property
    def api_key_list(self) -> list[str]:
        return [k.strip() for k in self.api_keys.split(",") if k.strip()]

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()
