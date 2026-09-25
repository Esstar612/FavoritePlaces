from fastapi import FastAPI

from outing_agent import config  # noqa: F401  loads agent/.env at startup

app = FastAPI(title="Favorite Places Outing Agent")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
