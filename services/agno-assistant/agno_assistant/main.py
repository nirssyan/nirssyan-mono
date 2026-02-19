import logging

import uvicorn
from fastapi import FastAPI
from pydantic import BaseModel

from agno_assistant.agent import create_agent
from agno_assistant.config import settings

logger = logging.getLogger(__name__)

app = FastAPI(title="Infatium Assistant", version="0.1.0")

agent = create_agent()


class ChatRequest(BaseModel):
    message: str
    user_id: str
    session_id: str | None = None


class ChatResponse(BaseModel):
    content: str


@app.get("/healthz")
def healthz():
    return {"status": "ok"}


@app.post("/v1/chat")
def chat(req: ChatRequest):
    session_id = req.session_id or req.user_id
    response = agent.run(
        req.message,
        user_id=req.user_id,
        session_id=session_id,
    )
    content = response.content if response and response.content else ""
    return ChatResponse(content=content)


def main():
    logging.basicConfig(
        level=logging.DEBUG if settings.debug else logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )
    uvicorn.run(
        "agno_assistant.main:app",
        host=settings.host,
        port=settings.port,
        log_level="debug" if settings.debug else "info",
    )


if __name__ == "__main__":
    main()
