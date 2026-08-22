#!/usr/bin/env python3
from pathlib import Path
import contextlib
import hashlib
import importlib.metadata as md
import json
import os
import platform
import subprocess
import sys

out = Path(sys.argv[1] if len(sys.argv) > 1 else '/evidence')
out.mkdir(parents=True, exist_ok=True)

EXPECTED = {
    'pip': '26.1.2',
    'numpy': '2.4.6',
    'scipy': '1.17.1',
    'pytest': '9.1.1',
    'iniconfig': '2.3.0',
    'packaging': '26.3',
    'pluggy': '1.6.0',
    'Pygments': '2.21.0',
}
THREADS = [
    'OMP_NUM_THREADS',
    'OPENBLAS_NUM_THREADS',
    'MKL_NUM_THREADS',
    'VECLIB_MAXIMUM_THREADS',
    'NUMEXPR_NUM_THREADS',
    'BLIS_NUM_THREADS',
]


def sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def capture(cmd, path, required=True):
    p = subprocess.run(cmd, text=True, capture_output=True, check=False)
    Path(path).write_text(
        '$ ' + ' '.join(cmd)
        + '\nRETURN_CODE=' + str(p.returncode)
        + '\nSTDOUT\n' + p.stdout
        + '\nSTDERR\n' + p.stderr,
        encoding='utf-8',
    )
    if required and p.returncode != 0:
        raise SystemExit('COMMAND_FAIL ' + repr(cmd))
    return p


if sys.version_info[:3] != (3, 13, 14):
    raise SystemExit('PYTHON_VERSION_FAIL ' + sys.version)
if platform.machine() != 'x86_64':
    raise SystemExit('ARCH_FAIL ' + platform.machine())

thread_values = {k: os.environ.get(k) for k in THREADS}
if any(v != '1' for v in thread_values.values()):
    raise SystemExit('THREAD_ENV_FAIL ' + repr(thread_values))

versions = {k: md.version(k) for k in EXPECTED}
if versions != EXPECTED:
    raise SystemExit('PACKAGE_VERSION_FAIL ' + repr(versions))

import numpy as np
import scipy
import numpy._core._multiarray_umath as np_core
import scipy.linalg._fblas as scipy_fblas

with (out / 'numpy_show_config.txt').open('w', encoding='utf-8') as f:
    with contextlib.redirect_stdout(f):
        np.show_config()

try:
    import scipy.__config__ as scipy_config
    with (out / 'scipy_show_config.txt').open('w', encoding='utf-8') as f:
        with contextlib.redirect_stdout(f):
            scipy_config.show()
except Exception as exc:
    raise SystemExit('SCIPY_CONFIG_CAPTURE_FAIL ' + repr(exc))

capture(['ldd', str(Path(np_core.__file__).resolve())], out / 'numpy_core_ldd.txt')
capture(['ldd', str(Path(scipy_fblas.__file__).resolve())], out / 'scipy_fblas_ldd.txt')

try:
    cpuinfo = Path('/proc/cpuinfo').read_text(encoding='utf-8', errors='replace')
except Exception as exc:
    cpuinfo = 'ERROR ' + repr(exc)
(out / 'proc_cpuinfo.txt').write_text(cpuinfo, encoding='utf-8')

flags = []
for line in cpuinfo.splitlines():
    if line.lower().startswith(('flags', 'features')):
        flags = line.split(':', 1)[1].strip().split() if ':' in line else []
        break

record = {
    'schema': 'NREF_GENERIC_NUMENV_QUALIFICATION_IDENTITY_v1.0',
    'status': 'PASS',
    'python_version': sys.version,
    'python_executable': str(Path(sys.executable).resolve()),
    'python_executable_sha256': sha256(Path(sys.executable).resolve()),
    'machine': platform.machine(),
    'platform': platform.platform(),
    'libc': platform.libc_ver(),
    'packages': versions,
    'thread_environment': thread_values,
    'numpy_version': np.__version__,
    'scipy_version': scipy.__version__,
    'numpy_core_extension': str(Path(np_core.__file__).resolve()),
    'scipy_fblas_extension': str(Path(scipy_fblas.__file__).resolve()),
    'cpu_flags': flags,
    'blas_lapack_provider_evidence': [
        'numpy_show_config.txt',
        'scipy_show_config.txt',
        'numpy_core_ldd.txt',
        'scipy_fblas_ldd.txt',
    ],
}
(out / 'qualification_environment_status.json').write_text(
    json.dumps(record, indent=2, sort_keys=True) + '\n', encoding='utf-8'
)
print('QUALIFICATION_ENVIRONMENT_VERIFY=PASS')
