#!/usr/bin/env python3
from pathlib import Path
import json
import os

root = Path(__file__).resolve().parents[1]
status_path = root / 'evidence/status/controlled_numenv_status.json'
if not status_path.exists():
    raise SystemExit('CONTROLLED_STATUS_MISSING')
status = json.loads(status_path.read_text(encoding='utf-8'))

checks = {
    'controlled_status': status.get('overall_status') == 'PASS',
    'finalize_status_outcome': os.environ.get('FINALIZE_STATUS_OUTCOME') == 'success',
    'package_evidence_outcome': os.environ.get('PACKAGE_EVIDENCE_OUTCOME') == 'success',
    'upload_evidence_outcome': os.environ.get('UPLOAD_EVIDENCE_OUTCOME') == 'success',
    'record_transport_outcome': os.environ.get('RECORD_TRANSPORT_OUTCOME') == 'success',
    'upload_transport_outcome': os.environ.get('UPLOAD_TRANSPORT_OUTCOME') == 'success',
}
failed = [key for key, value in checks.items() if not value]
if failed:
    raise SystemExit('GENERIC_NUMENV_CONTROLLED_GATE_FAIL ' + ','.join(failed))
print('GENERIC_NUMENV_CONTROLLED_GATE=PASS')
