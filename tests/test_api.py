import json
import os
import sys

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "app"))

from main import app


@pytest.fixture
def client():
    app.config["TESTING"] = True
    with app.test_client() as client:
        yield client


def test_health_endpoint(client):
    response = client.get("/health")
    assert response.status_code == 200
    data = json.loads(response.data)
    assert data["status"] == "healthy"


def test_home_endpoint(client):
    response = client.get("/")
    assert response.status_code == 200
    data = json.loads(response.data)
    assert "message" in data
    assert "endpoints" in data


def test_analyze_endpoint_valid(client):
    response = client.post(
        "/analyze", json={"text": "This is amazing!"}, content_type="application/json"
    )
    assert response.status_code == 200
    data = json.loads(response.data)
    assert "sentiment" in data
    assert "confidence" in data


def test_analyze_endpoint_empty_text(client):
    response = client.post(
        "/analyze", json={"text": ""}, content_type="application/json"
    )
    assert response.status_code == 400


def test_analyze_endpoint_no_json(client):
    response = client.post("/analyze")
    assert response.status_code == 400


def test_stats_endpoint_empty(client):
    response = client.get("/stats")
    assert response.status_code == 200
    data = json.loads(response.data)
    assert "stats" in data


def test_history_endpoint(client):
    response = client.get("/history")
    assert response.status_code == 200
    data = json.loads(response.data)
    assert "count" in data
    assert "history" in data
