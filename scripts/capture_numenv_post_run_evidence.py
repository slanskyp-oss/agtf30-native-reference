#!/usr/bin/env python3
from pathlib import Path
import hashlib
import shutil

root = Path(__file__).resolve().parents[1]
evidence = root / 'evidence'
if not evidence.exists():
    raise SystemExit('EVIDENCE_ROOT_MISSING')

harness = evidence / 'harness'
harness.mkdir(parents=True, exist_ok=True)
copy_paths = [
    'action_dependency_register.json',
    'PUBLIC_CONTENT_ALLOWLIST.json',
    'PUBLIC_REPOSITORY_POLICY.md',
    'TEMPLATE_SHA256SUMS.txt',
    '.github/workflows/generic-python-numenv-v1-controlled.yml',
    'config/generic_python_numenv_policy.json',
    'config/generic_python_numenv_wheelhouse.csv',
    'config/generic_python_numenv_wheelhouse_sha256.txt',
    'config/generic_python_numenv_requirements.lock',
    'config/generic_python_numenv_pip_bootstrap.lock',
    'docs/GENERIC_PYTHON_NUMENV_ACQUISITION.md',
    'tools/generic_numenv_static_check.py',
]
for rel in copy_paths:
    src = root / rel
    if not src.exists():
        raise SystemExit('HARNESS_EVIDENCE_SOURCE_MISSING ' + rel)
    dst = harness / rel.replace('/', '__')
    shutil.copy2(src, dst)

manifest = evidence / 'SHA256SUMS.txt'
if manifest.exists():
    manifest.unlink()

rows = []
for path in sorted(p for p in evidence.rglob('*') if p.is_file() and p != manifest):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    rows.append(f'{h.hexdigest()}  {path.relative_to(evidence).as_posix()}')

manifest.write_text('\n'.join(rows) + '\n', encoding='ascii')

# Self-check the manifest just generated.
for line in manifest.read_text(encoding='ascii').splitlines():
    expected, rel = line.split('  ', 1)
    path = evidence / rel
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    actual = h.hexdigest()
    if actual != expected:
        raise SystemExit('EVIDENCE_MANIFEST_SELF_CHECK_FAIL ' + rel)

(evidence / 'EVIDENCE_FILE_COUNT.txt').write_text(
    str(len(rows)) + '\n', encoding='ascii'
)
print('GENERIC_NUMENV_EVIDENCE_MANIFEST=PASS files=' + str(len(rows)))
