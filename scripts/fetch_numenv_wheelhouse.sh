#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$ROOT/config/generic_python_numenv_wheelhouse.csv"
EXPECTED="$ROOT/config/generic_python_numenv_wheelhouse_sha256.txt"
OUT="$ROOT/evidence/wheelhouse"

rm -rf "$OUT"
mkdir -p "$OUT"
cp "$MANIFEST" "$OUT/"
cp "$EXPECTED" "$OUT/EXPECTED_SHA256SUMS.txt"

count=0
while IFS=, read -r package version filename url expected_sha role; do
  if [[ "$package" == "Package" ]]; then
    continue
  fi
  role="${role%$'\r'}"
  expected_sha="${expected_sha%$'\r'}"
  tmp="$OUT/$filename.tmp"
  final="$OUT/$filename"

  printf 'ACQUIRE package=%s version=%s file=%s role=%s\n' \
    "$package" "$version" "$filename" "$role"

  curl --fail --location --silent --show-error \
    --proto '=https' --tlsv1.2 --retry 3 --retry-delay 2 \
    --output "$tmp" "$url"

  got="$(sha256sum "$tmp" | awk '{print $1}')"
  if [[ "$got" != "$expected_sha" ]]; then
    printf 'WHEEL_HASH_FAIL file=%s expected=%s got=%s\n' \
      "$filename" "$expected_sha" "$got" >&2
    exit 20
  fi

  mv "$tmp" "$final"
  count=$((count + 1))
done < "$MANIFEST"

[[ "$count" -eq 8 ]] || {
  echo "WHEEL_COUNT_FAIL got=$count expected=8" >&2
  exit 21
}

(
  cd "$OUT"
  sha256sum *.whl | sort -k2 > WHEELHOUSE_SHA256SUMS.txt
  sort -k2 EXPECTED_SHA256SUMS.txt > expected.sorted
  sort -k2 WHEELHOUSE_SHA256SUMS.txt > actual.sorted
  diff -u expected.sorted actual.sorted
  rm expected.sorted actual.sorted
)

python3 - "$OUT" <<'__PY__'
from pathlib import Path
import json
import sys

out = Path(sys.argv[1])
wheels = sorted(p.name for p in out.glob('*.whl'))
obj = {
    'schema': 'NREF_GENERIC_NUMENV_WHEELHOUSE_ACQUISITION_STATUS_v1.0',
    'status': 'PASS',
    'wheel_count': len(wheels),
    'wheels': wheels,
}
(out / 'wheelhouse_acquisition_status.json').write_text(
    json.dumps(obj, indent=2) + '\n', encoding='utf-8'
)
__PY__

echo 'WHEELHOUSE_FETCH_VERIFY=PASS'
