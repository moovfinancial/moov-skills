#!/usr/bin/env bash
# Combines all topic-specific SKILL.md files into a single SKILL-full.md
# Usage: bash scripts/combine-skills.sh

set -euo pipefail

SKILLS_DIR="moov-api"
OUTPUT="$SKILLS_DIR/SKILL-full.md"

# Order matters: core first, then topics
FILES=(
  "$SKILLS_DIR/SKILL.md"
  "$SKILLS_DIR/accounts/SKILL.md"
  "$SKILLS_DIR/payment-sources/SKILL.md"
  "$SKILLS_DIR/money-movement/SKILL.md"
  "$SKILLS_DIR/commerce/SKILL.md"
  "$SKILLS_DIR/issuing/SKILL.md"
)

: > "$OUTPUT"

for f in "${FILES[@]}"; do
  if [[ ! -f "$f" ]]; then
    echo "Warning: $f not found, skipping" >&2
    continue
  fi
  # Strip YAML frontmatter (everything between first --- and second ---)
  awk 'NR==1 && /^---$/ {f=1; next} f && /^---$/ {f=0; next} !f' "$f" >> "$OUTPUT"
  echo "" >> "$OUTPUT"
done

echo "Combined skill written to $OUTPUT"
