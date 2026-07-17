#!/usr/bin/env bash
# Update image tags in Kustomize overlays + Helm values after a successful CI build.
# Usage: OWNER=myorg ./scripts/update-image-tags.sh <sha> [version]
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHA="${1:?git sha required}"
VERSION="${2:-}"
REGISTRY="${REGISTRY:-ghcr.io}"
OWNER="${OWNER:-${GITHUB_REPOSITORY_OWNER:-amaninsa}}"
OWNER="${OWNER,,}"

update_kustomize_tags() {
  local file="$1"
  local tag="$2"
  python3 - "$file" "$tag" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
tag = sys.argv[2]
if not path.exists():
    raise SystemExit(0)

known = {
    "owasp-juiceshop-chatbot-chromadb",
    "owasp-juiceshop-chatbot-backend",
    "owasp-juiceshop-chatbot-frontend",
}
lines = path.read_text().splitlines()
out = []
pending = None
for line in lines:
    m = re.search(r"newName:\s*.*/(owasp-juiceshop-chatbot-[a-z0-9-]+)$", line)
    if m and m.group(1) in known:
        pending = m.group(1)
        out.append(line)
        continue
    if pending and "newTag:" in line:
        quote = '"' if '"' in line else ""
        out.append(re.sub(r"(newTag:\s*).*", rf"\1{quote}{tag}{quote}", line))
        pending = None
        continue
    out.append(line)

path.write_text("\n".join(out) + "\n")
print(f"Updated {path} -> {tag}")
PY
}

update_helm_tags() {
  local file="$1"
  local tag="$2"
  python3 - "$file" "$tag" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
tag = sys.argv[2]
if not path.exists():
    raise SystemExit(0)

text = path.read_text()
# Replace tag under image: blocks for our three services
text = re.sub(
    r"(repository:\s*owasp-juiceshop-chatbot-(?:frontend|backend|chromadb)\s*\n\s*tag:\s*)[^\n]+",
    rf'\1"{tag}"',
    text,
)
path.write_text(text)
print(f"Updated {path} -> {tag}")
PY
}

update_kustomize_tags "${ROOT_DIR}/apps/overlays/dev/kustomization.yaml" "${SHA}"
update_helm_tags "${ROOT_DIR}/helm/values-dev.yaml" "${SHA}"

if [[ -n "${VERSION}" ]]; then
  update_kustomize_tags "${ROOT_DIR}/apps/overlays/prod/kustomization.yaml" "${VERSION}"
  update_helm_tags "${ROOT_DIR}/helm/values.yaml" "${VERSION}"
fi

echo "Image tags updated (registry=${REGISTRY} owner=${OWNER} sha=${SHA} version=${VERSION:-n/a})"
