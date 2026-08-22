#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WHEELHOUSE="$ROOT/evidence/wheelhouse"
OCI="$ROOT/evidence/oci"
OUT="$ROOT/evidence/install"
mkdir -p "$OUT"

IMMUTABLE_REF="docker.io/library/python@sha256:67a1e1f215ccda113cfc024e8639049257e88f273898f595b61476d128d387e8"
TARGET_PLATFORM="linux/amd64"
PIP_FILE="pip-26.1.2-py3-none-any.whl"
PIP_SHA="382ff9f685ee3bc25864f820aa50505825f10f5458ffff07e30a6d96e5715cab"

[[ -f "$OCI/oci_materialization_status.json" ]] || {
  echo 'OCI_STATUS_MISSING' >&2
  exit 40
}
[[ -f "$WHEELHOUSE/wheelhouse_acquisition_status.json" ]] || {
  echo 'WHEELHOUSE_STATUS_MISSING' >&2
  exit 41
}

# No image pull is allowed here; the exact digest must already be materialized.
docker run --rm --pull=never --platform "$TARGET_PLATFORM" --network none \
  -e OMP_NUM_THREADS=1 \
  -e OPENBLAS_NUM_THREADS=1 \
  -e MKL_NUM_THREADS=1 \
  -e VECLIB_MAXIMUM_THREADS=1 \
  -e NUMEXPR_NUM_THREADS=1 \
  -e BLIS_NUM_THREADS=1 \
  -e PIP_NO_INDEX=1 \
  -e PIP_DISABLE_PIP_VERSION_CHECK=1 \
  -e PIP_CONFIG_FILE=/dev/null \
  -e PYTHONHASHSEED=0 \
  -e TZ=UTC \
  -v "$WHEELHOUSE:/wheelhouse:ro" \
  -v "$ROOT:/harness:ro" \
  -v "$OUT:/evidence" \
  "$IMMUTABLE_REF" sh -lc '
    set -eux

    # Prove outbound isolation before any package installation.
    python - <<"PY" | tee /evidence/network_isolation_probe.txt
import socket
s = socket.socket()
s.settimeout(1.0)
try:
    s.connect(("1.1.1.1", 443))
except OSError as exc:
    print("NETWORK_ISOLATION_PROBE=PASS", repr(exc))
else:
    raise SystemExit("NETWORK_ISOLATION_PROBE=FAIL")
finally:
    s.close()
PY

    # S8-002: reverify all 8 wheel bytes inside --network none before any pip install.
    cd /wheelhouse
    sha256sum -c /harness/config/generic_python_numenv_wheelhouse_sha256.txt \
      | tee /evidence/wheelhouse_preinstall_hash_check.txt

    # Explicit second check of the bootstrap pip wheel immediately before consumption.
    echo "382ff9f685ee3bc25864f820aa50505825f10f5458ffff07e30a6d96e5715cab  pip-26.1.2-py3-none-any.whl" \
      | sha256sum -c - \
      | tee /evidence/pip_bootstrap_preinstall_hash_check.txt

    python --version | tee /evidence/python_version_preinstall.txt
    sha256sum "$(command -v python)" \
      | tee /evidence/python_executable_sha256_preinstall.txt
    python -m pip --version | tee /evidence/base_pip_version_prebootstrap.txt

    # Bootstrap only the exact verified pip wheel.
    python -m pip install --no-index --no-deps \
      /wheelhouse/pip-26.1.2-py3-none-any.whl \
      | tee /evidence/pip_bootstrap_install.log
    python -m pip --version | tee /evidence/pip_version_postbootstrap.txt

    # Exact local-wheel installation; no network, no sdist, all hashes required.
    python -m pip install --no-index --find-links=/wheelhouse \
      --only-binary=:all: --require-hashes \
      -r /harness/config/generic_python_numenv_requirements.lock \
      | tee /evidence/qualification_install.log

    python -m pip check | tee /evidence/pip_check.txt
    python -m pip freeze --all | sort | tee /evidence/pip_freeze_all.txt
    python -m pip list --format=json | tee /evidence/pip_list.json

    python /harness/scripts/verify_numenv_environment.py /evidence \
      | tee /evidence/qualification_environment_verify.log

    sha256sum "$(command -v python)" \
      | tee /evidence/python_executable_sha256_postinstall.txt
    diff -u \
      /evidence/python_executable_sha256_preinstall.txt \
      /evidence/python_executable_sha256_postinstall.txt
  '

(
  cd "$OUT"
  find . -maxdepth 1 -type f ! -name INSTALL_EVIDENCE_SHA256SUMS.txt -print0 \
    | sort -z \
    | xargs -0 sha256sum > INSTALL_EVIDENCE_SHA256SUMS.txt
)

echo 'NETWORK_DISABLED_INSTALL_AND_CAPTURE=PASS'
