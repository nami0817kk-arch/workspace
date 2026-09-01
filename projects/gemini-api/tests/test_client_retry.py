import asyncio

import pytest

from app.clients.gemini import GeminiClient, GeminiError
from app.config import Settings


class Boom(Exception):
    def __init__(self, code):
        super().__init__(f"{code} upstream")
        self.code = code


def make_client(**overrides):
    kwargs = {"max_retries": 1, "request_timeout": 5.0}
    kwargs.update(overrides)
    settings = Settings(gemini_api_key="test-key", _env_file=None, **kwargs)
    client = GeminiClient.__new__(GeminiClient)  # SDK を作らずにリトライ層だけ検証する
    client._settings = settings
    client._client = None
    return client


def run(coro):
    return asyncio.run(coro)


def test_non_retryable_status_passes_through_immediately():
    client = make_client()
    attempts = []

    async def call():
        attempts.append(1)
        raise Boom(404)

    with pytest.raises(GeminiError) as exc:
        run(client._with_retry(call, what="test"))
    assert exc.value.status_code == 404
    assert len(attempts) == 1


def test_retryable_status_retries_then_passes_through_503():
    client = make_client()
    attempts = []

    async def call():
        attempts.append(1)
        raise Boom(503)

    with pytest.raises(GeminiError) as exc:
        run(client._with_retry(call, what="test"))
    assert exc.value.status_code == 503
    assert len(attempts) == 2  # max_retries=1 -> 初回 + 1回


def test_upstream_500_is_rounded_to_502():
    client = make_client()

    async def call():
        raise Boom(500)

    with pytest.raises(GeminiError) as exc:
        run(client._with_retry(call, what="test"))
    assert exc.value.status_code == 502


def test_timeout_becomes_504():
    client = make_client(request_timeout=0.05, max_retries=0)

    async def call():
        await asyncio.sleep(1)

    with pytest.raises(GeminiError) as exc:
        run(client._with_retry(call, what="test"))
    assert exc.value.status_code == 504


def test_retry_succeeds_on_second_attempt():
    client = make_client()
    attempts = []

    async def call():
        attempts.append(1)
        if len(attempts) == 1:
            raise Boom(429)
        return "ok"

    assert run(client._with_retry(call, what="test")) == "ok"
    assert len(attempts) == 2
