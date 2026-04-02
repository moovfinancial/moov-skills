# Contributing to Moov Skills

Thank you for contributing to Moov's AI skills! This repo is the canonical source for AI coding assistant integration patterns used across the Moov platform.

## How to contribute

### Edit an existing skill

1. Fork this repo
2. Edit the relevant `SKILL.md` file under `moov-api/`
3. Run `bash scripts/combine-skills.sh` and verify the output isn't empty
4. Open a PR with a description of what you changed and why

### Add a new example prompt

1. Fork this repo
2. Create a new file in `examples/` (e.g., `examples/your-scenario.md`)
3. Follow the [example format](#example-format) below
4. Add an entry to `examples/README.md`
5. Open a PR

### Propose a new skill topic

If you think a new topic area should be added (e.g., a new Moov product), open an issue first to discuss.

## Skill file format

All `SKILL.md` files must have YAML frontmatter with `name` and `description` fields:

```markdown
---
name: Moov Topic Name
description: One-line description of what this skill covers.
---

# Moov Topic Name

Content here...
```

### Guidelines

- **Be opinionated**: Recommend one approach rather than listing all options. Default to hosted flows unless the developer specifies embedded.
- **Show code**: Include curl, Go, TypeScript, and Python examples where relevant.
- **Use real patterns**: Examples should be copy-pasteable with placeholder values.
- **Stay current**: Reference the latest stable API version and SDK versions.
- **Don't duplicate**: If something is covered in another skill file, link to it rather than repeating.

## Example format

Example prompts in `examples/` follow this template:

```markdown
# Scenario Name

## Context

1-2 paragraphs describing the platform or business that would use this integration.

## Prompt

The actual prompt to paste into your AI coding assistant.

## What the AI should generate

Brief description of expected output — what API calls, flows, and patterns the AI should produce.
```

## Testing

Before submitting a PR, run the combine script to verify your changes:

```bash
bash scripts/combine-skills.sh
```

This generates `moov-api/SKILL-full.md` from all topic files. The CI pipeline validates that:

1. All `SKILL.md` files have valid frontmatter (`name` and `description` fields)
2. The combine script runs successfully and produces non-empty output

## Code of conduct

This project follows Moov's [Code of Conduct](https://github.com/moov-io/.github/blob/master/CODE_OF_CONDUCT.md).
