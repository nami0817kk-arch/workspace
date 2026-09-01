import json

from app.clients.gemini import GeminiError


def _events(raw: str) -> list[str]:
    return [block for block in raw.split("\n\n") if block.strip()]


def test_stream_yields_chunks_then_done(client, fake_client):
    res = client.post("/v1/generate/stream", json={"prompt": "こんにちはと言って"})
    assert res.status_code == 200
    assert res.headers["content-type"].startswith("text/event-stream")

    events = _events(res.text)
    assert events[-1] == "data: [DONE]"

    texts = [json.loads(e[len("data: ") :])["text"] for e in events[:-1]]
    assert texts == ["こん", "にち", "は"]
    assert "".join(texts) == "こんにちは"


def test_stream_passes_options_through(client, fake_client):
    client.post(
        "/v1/generate/stream",
        json={"prompt": "要約して", "model": "gemini-3.7-flash", "temperature": 0.1},
    )
    call = fake_client.calls[0]
    assert call["stream"] is True
    assert call["model"] == "gemini-3.7-flash"
    assert call["temperature"] == 0.1


def test_stream_failure_before_first_chunk_becomes_error_event(client, fake_client):
    fake_client.error = GeminiError("上流が落ちた", 503)
    res = client.post("/v1/generate/stream", json={"prompt": "x"})

    # ヘッダ送信済みなので 200 のまま、本文で error イベントを流す
    assert res.status_code == 200
    events = _events(res.text)
    assert events[0].startswith("event: error")
    payload = json.loads(events[0].split("data: ", 1)[1])
    assert payload["status"] == 503
    assert "上流が落ちた" in payload["detail"]
    assert "data: [DONE]" not in res.text


def test_stream_failure_midway_emits_error_after_partial_text(client, fake_client):
    fake_client.error_after_chunks = GeminiError("途中で切断", 502)
    res = client.post("/v1/generate/stream", json={"prompt": "x"})

    events = _events(res.text)
    assert len(events) == 4  # 3チャンク + error
    assert events[-1].startswith("event: error")
    assert "data: [DONE]" not in res.text


def test_stream_is_not_cached(make_client_for, fake_client):
    from fastapi.testclient import TestClient

    app = make_client_for(cache_ttl=60)
    with TestClient(app) as c:
        c.post("/v1/generate/stream", json={"prompt": "同じ質問"})
        c.post("/v1/generate/stream", json={"prompt": "同じ質問"})

    assert len(fake_client.calls) == 2
