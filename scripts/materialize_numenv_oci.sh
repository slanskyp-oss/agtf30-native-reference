#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/evidence/oci"
rm -rf "$OUT"
mkdir -p "$OUT"

FROZEN_DIGEST="sha256:67a1e1f215ccda113cfc024e8639049257e88f273898f595b61476d128d387e8"
IMAGE_REPO="docker.io/library/python"
IMMUTABLE_REF="${IMAGE_REPO}@${FROZEN_DIGEST}"
TARGET_PLATFORM="linux/amd64"

printf '%s\n' "$IMMUTABLE_REF" > "$OUT/REQUESTED_IMMUTABLE_REFERENCE.txt"
printf '%s\n' "$TARGET_PLATFORM" > "$OUT/REQUESTED_PLATFORM.txt"

# Resolve the frozen digest object and identify the exact linux/amd64 child
# manifest before local materialization. GitHub-hosted ubuntu runners include
# Docker Buildx; absence/failure is a controlled evidence failure.
docker buildx version > "$OUT/BUILDX_VERSION.txt" 2>&1
docker buildx imagetools inspect "$IMMUTABLE_REF" \
  > "$OUT/IMAGETOOLS_INSPECT.txt" 2>&1
docker buildx imagetools inspect --raw "$IMMUTABLE_REF" \
  > "$OUT/IMAGETOOLS_RAW.json"

python3 - "$OUT/IMAGETOOLS_RAW.json" "$FROZEN_DIGEST" <<'__PY_INDEX__'
import hashlib
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
frozen = sys.argv[2]
raw = path.read_bytes()
obj = json.loads(raw)
media = str(obj.get('mediaType', ''))
result = {
    'schema': 'NREF_GENERIC_NUMENV_REGISTRY_INDEX_RESOLUTION_v1.0',
    'frozen_digest': frozen,
    'raw_descriptor_sha256': 'sha256:' + hashlib.sha256(raw).hexdigest(),
    'mediaType': media,
}
if isinstance(obj.get('manifests'), list):
    candidates = [
        m for m in obj['manifests']
        if m.get('platform', {}).get('os') == 'linux'
        and m.get('platform', {}).get('architecture') == 'amd64'
        and not m.get('platform', {}).get('variant')
    ]
    if len(candidates) != 1:
        raise SystemExit('LINUX_AMD64_MANIFEST_SELECTION_FAIL count=' + str(len(candidates)))
    child = candidates[0]
    result['descriptor_kind'] = 'multi_platform_index'
    result['linux_amd64_manifest_digest'] = child.get('digest')
    result['linux_amd64_manifest_size'] = child.get('size')
    result['linux_amd64_manifest_mediaType'] = child.get('mediaType')
else:
    # If the frozen digest resolves directly to a single image manifest, the
    # platform-specific content digest is the frozen digest itself.
    result['descriptor_kind'] = 'single_manifest'
    result['linux_amd64_manifest_digest'] = frozen

digest = result.get('linux_amd64_manifest_digest')
if not isinstance(digest, str) or not digest.startswith('sha256:') or len(digest) != 71:
    raise SystemExit('LINUX_AMD64_MANIFEST_DIGEST_FAIL ' + repr(digest))
path.with_name('REGISTRY_INDEX_RESOLUTION.json').write_text(
    json.dumps(result, indent=2, sort_keys=True) + '\n', encoding='utf-8'
)
path.with_name('LINUX_AMD64_MANIFEST_DIGEST.txt').write_text(digest + '\n', encoding='ascii')
print('LINUX_AMD64_MANIFEST_RESOLUTION=PASS', digest)
__PY_INDEX__

# S8-001: acquire by immutable digest, never by mutable tag.
docker pull --platform "$TARGET_PLATFORM" "$IMMUTABLE_REF" \
  2>&1 | tee "$OUT/docker_pull.log"

docker image inspect "$IMMUTABLE_REF" > "$OUT/IMAGE_INSPECT.json"
docker image inspect "$IMMUTABLE_REF" --format '{{json .RepoDigests}}' \
  > "$OUT/REPO_DIGESTS.json"
docker image inspect "$IMMUTABLE_REF" --format '{{.Id}}' \
  > "$OUT/IMAGE_ID.txt"
docker image inspect "$IMMUTABLE_REF" --format '{{.Os}}/{{.Architecture}}' \
  > "$OUT/IMAGE_PLATFORM.txt"

actual_platform="$(cat "$OUT/IMAGE_PLATFORM.txt")"
[[ "$actual_platform" == "$TARGET_PLATFORM" ]] || {
  echo "PLATFORM_FAIL expected=$TARGET_PLATFORM actual=$actual_platform" >&2
  exit 31
}

python3 - "$OUT/REPO_DIGESTS.json" "$FROZEN_DIGEST" <<'__PY__'
import json
import sys

refs = json.load(open(sys.argv[1], encoding='utf-8'))
digest = sys.argv[2]
if not isinstance(refs, list) or not any(('@' + digest) in ref for ref in refs):
    raise SystemExit('FROZEN_DIGEST_RELATION_FAIL refs=' + repr(refs))
print('FROZEN_DIGEST_RELATION=PASS')
__PY__

# Save the exact materialized image by image ID/config digest and hash the archive.
IMAGE_ID="$(cat "$OUT/IMAGE_ID.txt")"
docker save "$IMAGE_ID" -o "$OUT/python-3.13.14-slim-bookworm-linux-amd64.tar"
sha256sum "$OUT/python-3.13.14-slim-bookworm-linux-amd64.tar" \
  > "$OUT/OCI_DOCKER_SAVE_SHA256.txt"

# Capture the base Python executable identity from the already-materialized image,
# with no network and no opportunity to pull a different image.
docker run --rm --pull=never --platform "$TARGET_PLATFORM" --network none \
  "$IMMUTABLE_REF" sh -lc '
    set -eu
    python --version
    command -v python
    sha256sum "$(command -v python)"
    uname -a
    ldd --version | head -n 2 || true
  ' > "$OUT/BASE_IMAGE_RUNTIME_CAPTURE.txt"

python3 - "$OUT" "$IMMUTABLE_REF" "$TARGET_PLATFORM" <<'__PY__'
from pathlib import Path
import hashlib
import json
import sys

out = Path(sys.argv[1])
ref = sys.argv[2]
platform = sys.argv[3]

def sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()

obj = {
    'schema': 'NREF_GENERIC_NUMENV_OCI_MATERIALIZATION_STATUS_v1.0',
    'status': 'PASS',
    'requested_immutable_reference': ref,
    'target_platform': platform,
    'repo_digests': json.loads((out / 'REPO_DIGESTS.json').read_text()),
    'registry_index_resolution': json.loads((out / 'REGISTRY_INDEX_RESOLUTION.json').read_text()),
    'linux_amd64_manifest_digest': (out / 'LINUX_AMD64_MANIFEST_DIGEST.txt').read_text().strip(),
    'image_id': (out / 'IMAGE_ID.txt').read_text().strip(),
    'actual_platform': (out / 'IMAGE_PLATFORM.txt').read_text().strip(),
    'saved_image_sha256': sha256(out / 'python-3.13.14-slim-bookworm-linux-amd64.tar'),
}
(out / 'oci_materialization_status.json').write_text(
    json.dumps(obj, indent=2) + '\n', encoding='utf-8'
)
__PY__

(
  cd "$OUT"
  find . -maxdepth 1 -type f ! -name OCI_EVIDENCE_SHA256SUMS.txt -print0 \
    | sort -z \
    | xargs -0 sha256sum > OCI_EVIDENCE_SHA256SUMS.txt
)

echo 'OCI_MATERIALIZATION=PASS'
