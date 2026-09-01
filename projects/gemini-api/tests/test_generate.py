from app.clients.gemini import GeminiError


def test_generate_returns_text_and_usage(client, fake_client):
    res = client.post("/v1/generate", json={"prompt": "こんにちはと言って"})
    assert res.status_code == 200
    body = res.json()
    assert body["text"] == "こんにちは"
    assert body["cached"] is False
    assert body["usage"]["total_tokens"] == 5
    assert fake_client.calls[0]["prompt"] == "こんにちはと言って"


def test_generate_passes_through_options(client, fake_client):
    res = client.post(
        "/v1/generate",
        json={
            "prompt": "要約して",
            "system_instruction": "あなたは要約の専門家です",
            "model": "gemini-3.5-flash",
            "temperature": 0.2,
            "max_output_tokens": 128,
        },
    )
    assert res.status_code == 200
    call = fake_client.calls[0]
    assert call["system_instruction"] == "あなたは要約の専門家です"
    assert call["model"] == "gemini-3.5-flash"
    assert call["temperature"] == 0.2
    assert call["max_output_tokens"] == 128


def test_empty_prompt_is_rejected(client):
    res = client.post("/v1/generate", json={"prompt": ""})
    assert res.status_code == 422


def test_temperature_out_of_range_is_rejected(client):
    res = client.post("/v1/generate", json={"prompt": "x", "temperature": 5})
    assert res.status_code == 422


def test_upstream_error_maps_to_status(client, fake_client):
    fake_client.error = GeminiError("rate limited", 429)
    res = client.post("/v1/generate", json={"prompt": "x"})
    assert res.status_code == 429
    assert "rate limited" in res.json()["detail"]


def test_cache_hit_skips_upstream(make_client_for, fake_client):
    from fastapi.testclient import TestClient

    app = make_client_for(cache_ttl=60)  # メモリキャッシュが入る

    with TestClient(app) as c:
        first = c.post("/v1/generate", json={"prompt": "同じ質問"})
        second = c.post("/v1/generate", json={"prompt": "同じ質問"})

    assert first.json()["cached"] is False
    assert second.json()["cached"] is True
    assert second.json()["text"] == first.json()["text"]
    assert second.json()["usage"] == first.json()["usage"]
    assert len(fake_client.calls) == 1


def test_different_prompt_is_not_a_cache_hit(make_client_for, fake_client):
    from fastapi.testclient import TestClient

    app = make_client_for(cache_ttl=60)
    with TestClient(app) as c:
        c.post("/v1/generate", json={"prompt": "A"})
        second = c.post("/v1/generate", json={"prompt": "B"})

    assert second.json()["cached"] is False
    assert len(fake_client.calls) == 2


def test_list_models(client):
    res = client.get("/v1/models")
    assert res.status_code == 200
    body = res.json()
    assert body["count"] == 1
    assert body["models"][0]["name"] == "models/gemini-3.5-flash"
