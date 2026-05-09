## MCP client configuration

{
  "mcpServers": {
    "fetch": {
      "command": "npx",
      "args": ["mcp-fetch-server"]
    }
  }
}

## As a CLI

npx mcp-fetch <command> <url> [flags]

Or install globally:

npm install -g mcp-fetch-server
mcp-fetch <command> <url> [flags]

## CLI Usage

`mcp-fetch <command> <url> [flags]`

## Commands

| Command    | Description                                                              |
| ---------- | ------------------------------------------------------------------------ |
| `html`     | Fetch a URL<br> and return raw HTML                                      |
| `markdown` | Fetch a URL<br> and return Markdown                                      |
| `readable` | Fetch a URL<br> and return article content as Markdown (via Readability) |
| `txt`      | Fetch a URL<br> and return plain text                                    |
| `json`     | Fetch a URL<br> and return JSON                                          |
| `youtube`  | Fetch a<br> YouTube video transcript                                     |

## Flags

| Flag                | Description                                               |
| ------------------- | --------------------------------------------------------- |
| `--max-length <N>`  | Maximum<br> characters to return                          |
| `--start-index <N>` | Start from<br> this character index                       |
| `--proxy <URL>`     | Proxy URL                                                 |
| `--lang <code>`     | Language<br> code for YouTube transcripts (default: `en`) |
| `--help`            | Show help<br> message                                     |
| `--version`         | Show version                                              |

## Examples

### Fetch a page as markdown

mcp-fetch markdown https://example.com

### Extract article content without boilerplate

mcp-fetch readable https://example.com/blog/post

### Get a YouTube transcript in Spanish

mcp-fetch youtube https://www.youtube.com/watch?v=dQw4w9WgXcQ --lang es

### Fetch with a length limit

mcp-fetch html https://example.com --max-length 10000

### Fetch through a proxy

mcp-fetch json https://api.example.com/data --proxy [http://proxy:8080](http://proxy:8080/)


