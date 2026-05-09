import asyncio
import subprocess
from pathlib import Path

from flask import Flask, render_template, request
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

app = Flask(__name__)

PACKAGE_DIR = Path(__file__).parent
NODE_MODULES = PACKAGE_DIR / "node_modules"
MCP_BIN = NODE_MODULES / ".bin" / "mcp-fetch-server"


def ensure_npm_installed() -> None:
    if not MCP_BIN.exists():
        subprocess.run(["npm", "install"], cwd=PACKAGE_DIR, check=True)


async def _fetch_txt(url: str) -> str:
    server_params = StdioServerParameters(command=str(MCP_BIN), args=[])
    async with stdio_client(server_params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            result = await session.call_tool("fetch_txt", {"url": url})
            if result.content:
                item = result.content[0]
                return item.text if hasattr(item, "text") else str(item) # type: ignore
            return ""


@app.route("/", methods=["GET", "POST"])
def index():
    content = None
    url = ""
    error = None
    if request.method == "POST":
        url = request.form.get("url", "").strip()
        if url:
            try:
                content = asyncio.run(_fetch_txt(url))
            except Exception as exc:
                error = str(exc)
    return render_template("index.html", url=url, content=content, error=error)


def run() -> None:
    ensure_npm_installed()
    app.run()


if __name__ == "__main__":
    run()
