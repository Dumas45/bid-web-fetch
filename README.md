# bid-web-fetch

A simple demo Python application designed to demonstrate a simple installation and launch method for distributing Python applications that uses locally installed npm packages lile MCP server.

Install:
```bash
curl -fsSL https://github.com/Dumas45/bid-web-fetch/raw/refs/heads/master/install.sh | bash
```

Run:
```bash
bid-fetch
```

Uninstall:
```bash
bid-fetch --uninstall
```

## Application

A minimal Flask web app that fetches any URL as plain text using the
[mcp-fetch-server](https://www.npmjs.com/package/mcp-fetch-server) Node.js MCP server as the
underlying fetch engine.

## Prerequisites

- Python 3.12
- [Node.js and npm](https://nodejs.org/) — required to run `mcp-fetch-server`

## Usage

```bash
bid-fetch
```

On first launch the app will run `npm install` inside its package directory to pull in
`mcp-fetch-server`. Make sure `npm` is on your `PATH`.

Then open <http://127.0.0.1:5000>, paste any URL into the form, and click **Fetch**.
The page content is returned as plain text.

## Development

```bash
git clone https://github.com/dumas45/bid-web-fetch
cd bid-web-fetch
uv sync
uv run flask --app bid_fetch_mcp.main run
```

## License

MIT

