#!/usr/bin/env python3
from pathlib import Path
import hashlib
import json
import os
from datetime import datetime, timezone

root = Path(__file__).resolve().parents[1]
out = root / 'transport'
out.mkdir(parents=True, exist_ok=True)

required = [
    'PRIMARY_ARTIFACT_DIGEST',
    'PRIMARY_ARTIFACT_ID',
    'PRIMARY_ARTIFACT_URL',
]
for key in required:
    if not os.environ.get(key):
        raise SystemExit('TRANSPORT_INPUT_MISSING ' + key)

obj = {
    'schema': 'NREF_GENERIC_NUMENV_CI_ARTIFACT_TRANSPORT_RECORD_v1.0',
    'artifact_name': 'GENERIC_PYTHON_NUMENV_V1_CONTROLLED_EVIDENCE',
    'artifact_digest': os.environ['PRIMARY_ARTIFACT_DIGEST'],
    'artifact_id': os.environ['PRIMARY_ARTIFACT_ID'],
    'artifact_url': os.environ['PRIMARY_ARTIFACT_URL'],
    'GITHUB_REPOSITORY': os.environ.get('GITHUB_REPOSITORY'),
    'expected_harness_sha': os.environ.get('EXPECTED_HARNESS_SHA'),
    'actual_harness_sha': os.environ.get('GITHUB_SHA'),
    'GITHUB_WORKFLOW': os.environ.get('GITHUB_WORKFLOW'),
    'GITHUB_REF': os.environ.get('GITHUB_REF'),
    'GITHUB_ACTOR': os.environ.get('GITHUB_ACTOR'),
    'GITHUB_RUN_ID': os.environ.get('GITHUB_RUN_ID'),
    'GITHUB_RUN_ATTEMPT': os.environ.get('GITHUB_RUN_ATTEMPT'),
    'acquisition_utc': datetime.now(timezone.utc).isoformat(),
    'permanence': 'TRANSPORT_ONLY_IMPORT_TO_CONTROLLED_DOWNSTREAM_STORAGE_REQUIRED',
    'downstream_authority_claimed': False,
}
path = out / 'ci_artifact_transport_record.json'
path.write_text(json.dumps(obj, indent=2, sort_keys=True) + '\n', encoding='utf-8')
record_hash = hashlib.sha256(path.read_bytes()).hexdigest()
(out / 'SHA256SUMS.txt').write_text(
    f'{record_hash}  ci_artifact_transport_record.json\n', encoding='ascii'
)
print('GENERIC_NUMENV_TRANSPORT_RECORD=PASS')
