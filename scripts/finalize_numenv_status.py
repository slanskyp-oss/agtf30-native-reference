#!/usr/bin/env python3
from pathlib import Path
import json
import os

root = Path(__file__).resolve().parents[1]
out = root / 'evidence' / 'status'
out.mkdir(parents=True, exist_ok=True)

step_keys = [
    'HARNESS_IDENTITY_OUTCOME',
    'RUNNER_IDENTITY_OUTCOME',
    'PUBLIC_ALLOWLIST_OUTCOME',
    'NUMENV_STATIC_OUTCOME',
    'WHEELHOUSE_OUTCOME',
    'OCI_OUTCOME',
    'OFFLINE_INSTALL_OUTCOME',
]
steps = {k: os.environ.get(k) for k in step_keys}
required_files = {
    'wheelhouse': root / 'evidence/wheelhouse/wheelhouse_acquisition_status.json',
    'oci': root / 'evidence/oci/oci_materialization_status.json',
    'install': root / 'evidence/install/qualification_environment_status.json',
}

file_status = {}
for key, path in required_files.items():
    try:
        obj = json.loads(path.read_text(encoding='utf-8'))
        file_status[key] = {
            'exists': True,
            'status': obj.get('status'),
            'path': str(path.relative_to(root)),
        }
    except Exception as exc:
        file_status[key] = {
            'exists': path.exists(),
            'status': 'MISSING_OR_INVALID',
            'error': repr(exc),
            'path': str(path.relative_to(root)),
        }

step_pass = all(value == 'success' for value in steps.values())
files_pass = all(value.get('status') == 'PASS' for value in file_status.values())
success = step_pass and files_pass

if success:
    code = 'GENERIC_PYTHON_NUMENV_CONTROLLED_EVIDENCE_CANDIDATE_PASS'
    detail = 'All controlled generic numerical-environment acquisition and qualification gates passed.'
else:
    failed = [k for k, v in steps.items() if v != 'success']
    failed += [
        f'{k}_STATUS'
        for k, v in file_status.items()
        if v.get('status') != 'PASS'
    ]
    code = 'GENERIC_PYTHON_NUMENV_CONTROLLED_EVIDENCE_FAIL'
    detail = 'Failed gates: ' + ', '.join(failed)

obj = {
    'schema': 'NREF_GENERIC_NUMENV_CONTROLLED_STATUS_v1.0',
    'overall_status': 'PASS' if success else 'FAIL',
    'classification': code,
    'detail': detail,
    'step_outcomes': steps,
    'machine_readable_evidence_status': file_status,
    'downstream_authority_claimed': False,
    'generic_environment_evidence_only': True,
}
(out / 'controlled_numenv_status.json').write_text(
    json.dumps(obj, indent=2, sort_keys=True) + '\n', encoding='utf-8'
)
print(code)
