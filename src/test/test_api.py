import src.main.app


app = src.main.app.create_app()
app.config["TESTING"] = True
client = app.test_client()


def test_true():
    """When all seems lost, the true test will always be there for you."""
    assert True


def test_healthcheck():
    response = client.get("/api/healthcheck")
    assert response.status_code == 200
    assert response.json == {"status": "ok"}
