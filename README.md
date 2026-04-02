# Moov AI Skills

AI skills for building payment integrations with the [Moov](https://moov.io) platform. Skills give your AI coding assistant offline knowledge of Moov's API patterns, SDKs, and best practices — so it generates correct, production-ready integration code.

Skills are served publicly at [docs.moov.io/skills/](https://docs.moov.io/skills/) and documented at [docs.moov.io/guides/get-started/ai-skill/](https://docs.moov.io/guides/get-started/ai-skill/).

## Quick install

### Claude Code

Claude Code auto-discovers skill files in `.claude/skills/`. Download all 6 topic-specific skills so Claude loads only what's relevant to each question:

```bash
mkdir -p .claude/skills/moov-api/accounts .claude/skills/moov-api/payment-sources .claude/skills/moov-api/money-movement .claude/skills/moov-api/commerce .claude/skills/moov-api/issuing

# From docs.moov.io
curl -sL https://docs.moov.io/skills/moov-api/SKILL.md -o .claude/skills/moov-api/SKILL.md
curl -sL https://docs.moov.io/skills/moov-api/accounts/SKILL.md -o .claude/skills/moov-api/accounts/SKILL.md
curl -sL https://docs.moov.io/skills/moov-api/payment-sources/SKILL.md -o .claude/skills/moov-api/payment-sources/SKILL.md
curl -sL https://docs.moov.io/skills/moov-api/money-movement/SKILL.md -o .claude/skills/moov-api/money-movement/SKILL.md
curl -sL https://docs.moov.io/skills/moov-api/commerce/SKILL.md -o .claude/skills/moov-api/commerce/SKILL.md
curl -sL https://docs.moov.io/skills/moov-api/issuing/SKILL.md -o .claude/skills/moov-api/issuing/SKILL.md
```

Or from GitHub:

```bash
mkdir -p .claude/skills/moov-api/accounts .claude/skills/moov-api/payment-sources .claude/skills/moov-api/money-movement .claude/skills/moov-api/commerce .claude/skills/moov-api/issuing

curl -sL https://raw.githubusercontent.com/moovfinancial/moov-skills/main/moov-api/SKILL.md -o .claude/skills/moov-api/SKILL.md
curl -sL https://raw.githubusercontent.com/moovfinancial/moov-skills/main/moov-api/accounts/SKILL.md -o .claude/skills/moov-api/accounts/SKILL.md
curl -sL https://raw.githubusercontent.com/moovfinancial/moov-skills/main/moov-api/payment-sources/SKILL.md -o .claude/skills/moov-api/payment-sources/SKILL.md
curl -sL https://raw.githubusercontent.com/moovfinancial/moov-skills/main/moov-api/money-movement/SKILL.md -o .claude/skills/moov-api/money-movement/SKILL.md
curl -sL https://raw.githubusercontent.com/moovfinancial/moov-skills/main/moov-api/commerce/SKILL.md -o .claude/skills/moov-api/commerce/SKILL.md
curl -sL https://raw.githubusercontent.com/moovfinancial/moov-skills/main/moov-api/issuing/SKILL.md -o .claude/skills/moov-api/issuing/SKILL.md
```

### Cursor

```bash
mkdir -p .cursor/rules/moov-api

curl -sL https://docs.moov.io/skills/moov-api/SKILL.md -o .cursor/rules/moov-api/core.md
curl -sL https://docs.moov.io/skills/moov-api/accounts/SKILL.md -o .cursor/rules/moov-api/accounts.md
curl -sL https://docs.moov.io/skills/moov-api/payment-sources/SKILL.md -o .cursor/rules/moov-api/payment-sources.md
curl -sL https://docs.moov.io/skills/moov-api/money-movement/SKILL.md -o .cursor/rules/moov-api/money-movement.md
curl -sL https://docs.moov.io/skills/moov-api/commerce/SKILL.md -o .cursor/rules/moov-api/commerce.md
curl -sL https://docs.moov.io/skills/moov-api/issuing/SKILL.md -o .cursor/rules/moov-api/issuing.md
```

Or download the combined file for older Cursor versions:

```bash
curl -sL https://docs.moov.io/skills/moov-api/SKILL-full.md -o .cursorrules
```

### Windsurf

```bash
curl -sL https://docs.moov.io/skills/moov-api/SKILL-full.md -o .windsurfrules
```

### GitHub Copilot / VS Code

```bash
curl -sL https://docs.moov.io/skills/moov-api/SKILL-full.md -o .github/copilot-instructions.md
```

### Codex CLI

```bash
curl -sL https://docs.moov.io/skills/moov-api/SKILL-full.md -o AGENTS.md
```

### ChatGPT / Manual

Download [SKILL-full.md](https://docs.moov.io/skills/moov-api/SKILL-full.md) and paste it into your conversation.

## Compatibility

| Tool | Config file | Auto-discovery |
|------|------------|----------------|
| Claude Code | `.claude/skills/moov-api/SKILL.md` | Yes — loads relevant skills per question |
| Cursor | `.cursor/rules/moov-api/*.md` or `.cursorrules` | Yes — rules loaded per session |
| Windsurf | `.windsurfrules` | Yes — loaded on session start |
| GitHub Copilot | `.github/copilot-instructions.md` | Yes — loaded per session |
| Codex CLI | `AGENTS.md` | Yes — loaded on agent start |
| VS Code | `.github/copilot-instructions.md` | Yes — loaded per session |
| ChatGPT / Manual | Paste into conversation | No — copy and paste |

## What's included

The skill covers the full Moov platform:

| Topic | File | What it covers |
|-------|------|----------------|
| **Core** | `moov-api/SKILL.md` | Mental model, auth, API versioning, errors, SDKs, webhooks, MCP server, test mode |
| **Accounts** | `moov-api/accounts/SKILL.md` | Account creation, capabilities, hosted onboarding, resolution links |
| **Payment sources** | `moov-api/payment-sources/SKILL.md` | Bank accounts, cards, Apple Pay, Google Pay, wallets, Moov.js/Drops |
| **Money movement** | `moov-api/money-movement/SKILL.md` | Transfers, refunds, disputes, transfer groups, scheduling, sweeps |
| **Commerce** | `moov-api/commerce/SKILL.md` | Payment links, invoices, receipts, enrichment |
| **Issuing** | `moov-api/issuing/SKILL.md` | Card issuing, tap to pay |

## Example prompts

See the [examples/](examples/) directory for integration recipes you can paste directly into your AI tool.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to contribute skills and example prompts.

## Full documentation

- [Moov AI skill guide](https://docs.moov.io/guides/get-started/ai-skill/) — Full setup instructions and comparison with other AI tools
- [Moov API reference](https://docs.moov.io/api/) — Rendered API documentation
- [Moov docs](https://docs.moov.io/) — Full documentation

## License

Apache 2.0 — see [LICENSE](LICENSE).
