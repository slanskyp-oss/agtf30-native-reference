#!/usr/bin/env python3
from pathlib import Path
import hashlib
import json
import os
import platform
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
out = root / 'evidence' / 'environment'
out.mkdir(parents=True, exist_ok=True)


def run(cmd):
    p = subprocess.run(cmd, text=True, capture_output=True, check=False)
    return {
        'command': cmd,
        'returncode': p.returncode,
        'stdout': p.stdout,
        'stderr': p.stderr,
    }


def sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


runner_env = {
    k: v
    for k, v in sorted(os.environ.items())
    if k.startswith(('RUNNER_', 'ACTIONS_RUNNER_'))
    or k in {'ImageOS', 'ImageVersion', 'GITHUB_ACTIONS'}
}
commands = {}
for name, cmd in {
    'uname': ['uname', '-a'],
    'os_release': ['cat', '/etc/os-release'],
    'lscpu': ['lscpu'],
    'docker_version': ['docker', 'version'],
    'docker_info': ['docker', 'info'],
    'docker_buildx_version': ['docker', 'buildx', 'version'],
    'git_version': ['git', '--version'],
    'bash_version': ['bash', '--version'],
    'python3_version': ['python3', '--version'],
    'sha256sum_version': ['sha256sum', '--version'],
    'curl_version': ['curl', '--version'],
}.items():
    commands[name] = run(cmd)

pyexe = Path(sys.executable).resolve()
record = {
    'schema': 'NREF_GENERIC_NUMENV_RUNNER_IDENTITY_v1.0',
    'RUNNER_OS': os.environ.get('RUNNER_OS'),
    'RUNNER_ARCH': os.environ.get('RUNNER_ARCH'),
    'ImageOS': os.environ.get('ImageOS'),
    'ImageVersion': os.environ.get('ImageVersion'),
    'platform': platform.platform(),
    'machine': platform.machine(),
    'host_python_version': sys.version,
    'host_python_executable': str(pyexe),
    'host_python_executable_sha256': sha256(pyexe),
    'runner_environment': runner_env,
    'commands': commands,
}
(out / 'runner_identity.json').write_text(
    json.dumps(record, indent=2, sort_keys=True) + '\n', encoding='utf-8'
)
try:
    (out / 'proc_cpuinfo.txt').write_text(
        Path('/proc/cpuinfo').read_text(encoding='utf-8', errors='replace'),
        encoding='utf-8',
    )
except Exception as exc:
    (out / 'proc_cpuinfo_error.txt').write_text(repr(exc) + '\n', encoding='utf-8')

if os.environ.get('RUNNER_OS') != 'Linux':
    raise SystemExit('RUNNER_OS_FAIL')
if os.environ.get('RUNNER_ARCH') != 'X64':
    raise SystemExit('RUNNER_ARCH_FAIL')
if commands['docker_version']['returncode'] != 0:
    raise SystemExit('DOCKER_UNAVAILABLE_FAIL')
print('GENERIC_NUMENV_RUNNER_IDENTITY=PASS')
