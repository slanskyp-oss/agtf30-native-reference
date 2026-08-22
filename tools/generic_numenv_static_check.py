#!/usr/bin/env python3
from pathlib import Path
import csv
import hashlib
import json
import re
import sys

root = Path(__file__).resolve().parents[1]
workflow = root / '.github/workflows/generic-python-numenv-v1-controlled.yml'
policy_path = root / 'config/generic_python_numenv_policy.json'
wheel_csv = root / 'config/generic_python_numenv_wheelhouse.csv'
wheel_sha = root / 'config/generic_python_numenv_wheelhouse_sha256.txt'
req_lock = root / 'config/generic_python_numenv_requirements.lock'
pip_lock = root / 'config/generic_python_numenv_pip_bootstrap.lock'
oci_script = root / 'scripts/materialize_numenv_oci.sh'
offline_script = root / 'scripts/run_numenv_offline_install.sh'
template = root / 'TEMPLATE_SHA256SUMS.txt'
allowlist_path = root / 'PUBLIC_CONTENT_ALLOWLIST.json'

required = [workflow, policy_path, wheel_csv, wheel_sha, req_lock, pip_lock,
            oci_script, offline_script, template, allowlist_path]
for path in required:
    if not path.is_file():
        raise SystemExit('GENERIC_NUMENV_STATIC_MISSING ' + str(path.relative_to(root)))

w = workflow.read_text(encoding='utf-8')
if 'workflow_dispatch:' not in w:
    raise SystemExit('GENERIC_NUMENV_TRIGGER_FAIL missing workflow_dispatch')
if re.search(r'(?m)^\s*(push|pull_request|schedule|repository_dispatch):', w):
    raise SystemExit('GENERIC_NUMENV_TRIGGER_FAIL non-manual trigger')
for marker in [
    'AUTHORIZE_CONTROLLED_NUMENV',
    'expected_harness_sha:',
    'EXPECTED_HARNESS_SHA: ${{ inputs.expected_harness_sha }}',
    'runs-on: ubuntu-24.04',
    './scripts/capture_harness_identity.ps1',
    'GENERIC_PYTHON_NUMENV_V1_CONTROLLED_EVIDENCE',
    'GENERIC_PYTHON_NUMENV_V1_TRANSPORT_RECORD',
]:
    if marker not in w:
        raise SystemExit('GENERIC_NUMENV_WORKFLOW_MARKER_FAIL ' + marker)

allowed_actions = {
    ('actions/checkout', '3d3c42e5aac5ba805825da76410c181273ba90b1'),
    ('actions/upload-artifact', '043fb46d1a93c77aae656e7c1c64a875d1fc6a0a'),
}
uses = []
for ref in re.findall(r'uses:\s*([^\s#]+)', w):
    m = re.fullmatch(r'([^@]+)@([0-9a-f]{40})', ref)
    if not m:
        raise SystemExit('GENERIC_NUMENV_ACTION_PIN_FAIL ' + ref)
    uses.append(m.groups())
if set(uses) != allowed_actions:
    raise SystemExit('GENERIC_NUMENV_ACTION_SET_FAIL ' + repr(uses))

policy = json.loads(policy_path.read_text(encoding='utf-8'))
if policy.get('schema') != 'NREF_GENERIC_PYTHON_NUMENV_POLICY_v1.0':
    raise SystemExit('GENERIC_NUMENV_POLICY_SCHEMA_FAIL')
image = policy.get('image', {})
frozen = image.get('frozen_registry_digest')
immutable = image.get('immutable_reference')
if frozen != 'sha256:67a1e1f215ccda113cfc024e8639049257e88f273898f595b61476d128d387e8':
    raise SystemExit('GENERIC_NUMENV_FROZEN_DIGEST_FAIL')
if immutable != 'docker.io/library/python@' + frozen:
    raise SystemExit('GENERIC_NUMENV_IMMUTABLE_REFERENCE_FAIL')
if image.get('target_platform') != 'linux/amd64' or image.get('python_version') != '3.13.14':
    raise SystemExit('GENERIC_NUMENV_IMAGE_POLICY_FAIL')

rows = list(csv.DictReader(wheel_csv.open(encoding='utf-8', newline='')))
if len(rows) != 8:
    raise SystemExit('GENERIC_NUMENV_WHEEL_COUNT_FAIL ' + str(len(rows)))
if len({r['Filename'] for r in rows}) != 8:
    raise SystemExit('GENERIC_NUMENV_WHEEL_FILENAME_UNIQUENESS_FAIL')
if any(not re.fullmatch(r'[0-9a-f]{64}', r['SHA256']) for r in rows):
    raise SystemExit('GENERIC_NUMENV_WHEEL_HASH_FORMAT_FAIL')
if any(not r['URL'].startswith('https://files.pythonhosted.org/') for r in rows):
    raise SystemExit('GENERIC_NUMENV_WHEEL_SOURCE_FAIL')
expected = {r['Filename']: r['SHA256'] for r in rows}
sha_rows = {}
for line in wheel_sha.read_text(encoding='ascii').splitlines():
    h, fn = line.split('  ', 1)
    sha_rows[fn] = h
if sha_rows != expected:
    raise SystemExit('GENERIC_NUMENV_WHEEL_HASH_MANIFEST_FAIL')

pip_rows = [r for r in rows if r['Package'] == 'pip']
if len(pip_rows) != 1 or pip_rows[0]['Version'] != '26.1.2':
    raise SystemExit('GENERIC_NUMENV_PIP_FREEZE_FAIL')
pip_line = pip_lock.read_text(encoding='utf-8').strip()
if pip_line != 'pip==26.1.2 --hash=sha256:' + pip_rows[0]['SHA256']:
    raise SystemExit('GENERIC_NUMENV_PIP_LOCK_FAIL')

non_pip = [r for r in rows if r['Package'] != 'pip']
req_lines = [x for x in req_lock.read_text(encoding='utf-8').splitlines() if x.strip()]
expected_req = {f"{r['Package']}=={r['Version']} --hash=sha256:{r['SHA256']}" for r in non_pip}
if set(req_lines) != expected_req or len(req_lines) != 7:
    raise SystemExit('GENERIC_NUMENV_REQUIREMENTS_LOCK_FAIL')

oci = oci_script.read_text(encoding='utf-8')
for marker in [
    'IMMUTABLE_REF="${IMAGE_REPO}@${FROZEN_DIGEST}"',
    'docker buildx imagetools inspect --raw "$IMMUTABLE_REF"',
    'LINUX_AMD64_MANIFEST_DIGEST.txt',
    'docker pull --platform "$TARGET_PLATFORM" "$IMMUTABLE_REF"',
    "--pull=never --platform \"$TARGET_PLATFORM\" --network none",
]:
    if marker not in oci:
        raise SystemExit('GENERIC_NUMENV_OCI_CONTROL_FAIL ' + marker)
# Reject an acquisition path that pulls the mutable Python tag.
if re.search(r'docker\s+pull[^\n]*python:3\.13\.14-slim-bookworm', oci):
    raise SystemExit('GENERIC_NUMENV_MUTABLE_IMAGE_PULL_FAIL')

off = offline_script.read_text(encoding='utf-8')
if '--network none' not in off or '--pull=never' not in off:
    raise SystemExit('GENERIC_NUMENV_OFFLINE_CONTAINER_CONTROL_FAIL')
first_install = off.find('python -m pip install')
full_hash = off.find('sha256sum -c /harness/config/generic_python_numenv_wheelhouse_sha256.txt')
pip_hash = off.find('pip_bootstrap_preinstall_hash_check.txt')
if min(first_install, full_hash, pip_hash) < 0 or not (full_hash < pip_hash < first_install):
    raise SystemExit('GENERIC_NUMENV_PREINSTALL_HASH_ORDER_FAIL')
for marker in ['--require-hashes', '--only-binary=:all:', '--no-index', 'PIP_NO_INDEX=1']:
    if marker not in off:
        raise SystemExit('GENERIC_NUMENV_PIP_OFFLINE_POLICY_FAIL ' + marker)

# The repository snapshot template is a hard static gate for every allowlisted
# tracked file except the template itself (self-hashing would be circular).
allow = json.loads(allowlist_path.read_text(encoding='utf-8'))['allowed_paths']
template_rows = {}
for line in template.read_text(encoding='ascii').splitlines():
    h, rel = line.split('  ', 1)
    template_rows[rel] = h
expected_paths = set(allow) - {'TEMPLATE_SHA256SUMS.txt'}
if set(template_rows) != expected_paths:
    raise SystemExit('GENERIC_NUMENV_TEMPLATE_COVERAGE_FAIL')
for rel, expected_hash in template_rows.items():
    path = root / rel
    if not path.is_file():
        raise SystemExit('GENERIC_NUMENV_TEMPLATE_FILE_MISSING ' + rel)
    actual = hashlib.sha256(path.read_bytes()).hexdigest()
    if actual != expected_hash:
        raise SystemExit('GENERIC_NUMENV_TEMPLATE_HASH_FAIL ' + rel)

print('GENERIC_NUMENV_STATIC_CHECK=PASS')
