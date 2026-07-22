#!/usr/bin/env bash
# Export Mermaid .mmd diagrams to PNG (requires Node + @mermaid-js/mermaid-cli).
# Usage: ./docs/diagrams/export-png.sh
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${DIR}"

if ! command -v npx >/dev/null 2>&1; then
  echo "npx required. Alternatively paste .mmd files into https://mermaid.live → PNG."
  exit 1
fi

for f in *.mmd; do
  out="${f%.mmd}.png"
  echo "Rendering ${f} → ${out}"
  npx --yes @mermaid-js/mermaid-cli@11.4.2 -i "${f}" -o "${out}" -b white
done
echo "Done. PNGs are PNG-compatible exports of the Mermaid sources."
