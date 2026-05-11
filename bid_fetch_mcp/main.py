import asyncio
from pathlib import Path

import spacy
from spacy.cli.download import download as spacy_download
from flask import Flask, render_template, request
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

app = Flask(__name__)

PACKAGE_DIR = Path(__file__).parent
NODE_MODULES = PACKAGE_DIR / "node_modules"
MCP_BIN = NODE_MODULES / ".bin" / "mcp-fetch-server"

APP_VERSION = '0.2.3'

try:
    nlp = spacy.load("en_core_web_sm")
except OSError:
    spacy_download("en_core_web_sm")
    nlp = spacy.load("en_core_web_sm")


def extract_svo(text: str) -> list[tuple[str, str, str]]:
    """Return a deduplicated list of (subject, verb-lemma, object) triplets."""
    doc = nlp(text)
    chunk_map: dict[int, str] = {chunk.root.i: chunk.text for chunk in doc.noun_chunks}
    seen: set[tuple[str, str, str]] = set()
    triplets: list[tuple[str, str, str]] = []
    for token in doc:
        if token.pos_ != "VERB":
            continue
        subject: str | None = None
        obj: str | None = None
        for child in token.children:
            if child.dep_ in ("nsubj", "nsubjpass") and subject is None:
                subject = chunk_map.get(child.i, child.text)
            elif child.dep_ in ("dobj", "attr", "obj", "pobj", "dative") and obj is None:
                obj = chunk_map.get(child.i, child.text)
        if subject and obj:
            triplet = (subject, token.lemma_, obj)
            if triplet not in seen:
                seen.add(triplet)
                triplets.append(triplet)
    return triplets


async def _fetch_url(url: str) -> str:
    server_params = StdioServerParameters(command=str(MCP_BIN), args=[])
    async with stdio_client(server_params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            result = await session.call_tool("fetch_readable", {"url": url})
            if result.content:
                item = result.content[0]
                return item.text if hasattr(item, "text") else str(item)  # type: ignore
            return ""


@app.route("/", methods=["GET", "POST"])
def index():
    triplets: list[tuple[str, str, str]] | None = None
    url = ""
    error = None
    if request.method == "POST":
        url = request.form.get("url", "").strip()
        if url:
            try:
                raw = asyncio.run(_fetch_url(url))
                triplets = extract_svo(raw)
            except Exception as exc:
                error = str(exc)
    return render_template("index.html", url=url, triplets=triplets, error=error, version=APP_VERSION)


def run() -> None:
    app.run()


if __name__ == "__main__":
    run()
