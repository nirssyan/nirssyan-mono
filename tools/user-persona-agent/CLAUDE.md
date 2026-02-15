# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Internal product-research tool that simulates a real user persona to find quality Telegram channels on a given topic via browser automation, then generates feed configuration recommendations for the Infatium app. Built on the Claude Agent SDK.

## Commands

```bash
# Install
npm install
# Also requires: agent-browser install && claude login

# First-time setup: copy Chrome profile (preserves Google login, cookies)
cp -a "$HOME/Library/Application Support/Google/Chrome" \
      "$HOME/Library/Application Support/Google/Chrome-debug"

# Terminal 1: Launch Chrome with remote debugging
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
  --remote-debugging-port=9222 \
  --user-data-dir="$HOME/Library/Application Support/Google/Chrome-debug"
# Open any tab in Chrome (required for CDP)

# Terminal 2: Run the agent
unset CLAUDECODE && npx tsx src/index.ts "Topic" personas/persona.md
```

No tests, no linter, no build step — this is a single-purpose CLI tool.

## Architecture

Single entry point `src/index.ts` that:
1. Parses CLI args: topic (required), persona (optional — `.md` file path or inline text, falls back to DEFAULT_PERSONA)
2. Reads `product-context.md` (Infatium feature docs embedded in system prompt)
3. Preflight: verifies Chrome remote debugging on port 9222, ensures a page tab exists, connects agent-browser via `--cdp 9222`
4. Builds a system prompt with persona + product context + phased browser automation instructions
5. Calls `query()` from `@anthropic-ai/claude-agent-sdk` (model: `claude-sonnet-4-5-20250929`, max 200 turns, $20 budget, only `Bash` tool allowed)
6. The spawned agent uses `agent-browser` via Bash — browser is already connected, no flags needed
7. Collects ALL assistant text blocks during execution, extracts markdown report via regex
8. Saves report to `output/{topic}-{timestamp}.md` and full log to `output/{topic}-{timestamp}.log`

## Key Files

- `src/index.ts` — all logic (preflight, prompt construction, SDK invocation, report extraction)
- `product-context.md` — Infatium product docs (feed types, views, filters) injected into system prompt
- `personas/*.md` — pre-built persona templates (crypto-trader, devops-engineer, product-manager)
- `output/` — generated reports + logs (gitignored)

## Agent Behavior

The agent's system prompt enforces strict rules:
- **3-phase workflow**: Phase 0 (check Telegram auth), Phase 1 (collect 60-80 candidates from tgstat + Google), Phase 2 (check 25+ channels in Telegram, subscribe to 10-15), Phase 3 (create folder + write report)
- **Must use `agent-browser`** for all web interaction — no other tools
- **Must read real posts** before including any channel in the report — "golden rule"
- Searches via Google (primary), tgstat.ru, telemetr.io, Telegram search, and snowball discovery (Similar Channels)
- Evaluates channels adaptively: 3 posts for obvious junk, 10-20 for promising ones
- Last response MUST be full markdown report starting with "# Моя лента:"
- Output is a first-person Russian-language markdown report

## Adding Personas

Create a `.md` file in `personas/` with 3-5 sentences describing the user character: background, expertise level, what content they value, what they dislike. See existing files for examples.
