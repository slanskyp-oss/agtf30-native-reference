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
    flat = rel.replace('/', '__')
    # upload-artifact defaults to include-hidden-files=false.  Never create a
    # flattened evidence filename beginning with '.', otherwise the internal
    # SHA256 manifest would reference a file omitted from the uploaded artifact.
    if flat.startswith('.'):
        flat = 'dot__' + flat[1:]
    dst = harness / flat
    shutil.copy2(src, dst)

manifest = evidence / 'SHA256SUMS.txt'
count_file = evidence / 'EVIDENCE_FILE_COUNT.txt'
for generated in (manifest, count_file):
    if generated.exists():
        generated.unlink()

# Fail closed if any evidence path component is hidden.  The controlled
# upload intentionally keeps include-hidden-files at its default false value.
# Therefore package completeness requires every manifest-referenced evidence
# object to be upload-visible.
for path in evidence.rglob('*'):
    rel_parts = path.relative_to(evidence).parts
    if any(part.startswith('.') for part in rel_parts):
        raise SystemExit('HIDDEN_EVIDENCE_PATH_FAIL ' + path.relative_to(evidence).as_posix())

# The count file is itself evidence and must be covered by SHA256SUMS.  Define
# its value as the number of non-manifest evidence files, including itself.
pre_count_files = sorted(p for p in evidence.rglob('*') if p.is_file())
expected_record_count = len(pre_count_files) + 1
count_file.write_text(str(expected_record_count) + '\n', encoding='ascii')

rows = []
for path in sorted(p for p in evidence.rglob('*') if p.is_file() and p != manifest):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    rows.append(f'{h.hexdigest()}  {path.relative_to(evidence).as_posix()}')

if len(rows) != expected_record_count:
    raise SystemExit(
        f'EVIDENCE_FILE_COUNT_FAIL expected={expected_record_count} actual={len(rows)}'
    )
manifest.write_text('\n'.join(rows) + '\n', encoding='ascii')

# Self-check the manifest just generated and require exact coverage of every
# non-manifest evidence object.
manifest_rel = {line.split('  ', 1)[1] for line in manifest.read_text(encoding='ascii').splitlines()}
actual_rel = {
    path.relative_to(evidence).as_posix()
    for path in evidence.rglob('*')
    if path.is_file() and path != manifest
}
if manifest_rel != actual_rel:
    missing = sorted(actual_rel - manifest_rel)
    extra = sorted(manifest_rel - actual_rel)
    raise SystemExit(f'EVIDENCE_MANIFEST_COVERAGE_FAIL missing={missing} extra={extra}')

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

print('GENERIC_NUMENV_EVIDENCE_MANIFEST=PASS files=' + str(len(rows)))
