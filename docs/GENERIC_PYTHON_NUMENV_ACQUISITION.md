# Generic Python Numerical Environment Acquisition v1.0

## Purpose

This controlled public workflow acquires and records a generic, reproducible Linux/Python numerical environment. It does not execute a propulsion model, a vehicle model, a mission analysis, or any downstream private engineering calculation.

The workflow is an additional CI/provenance lane in the public native-source reference repository. It reuses the repository's reviewed harness-SHA binding, immutable GitHub Action pinning, evidence-manifest convention, primary artifact digest, and separate transport-record convention.

## Information firewall

Required information flow remains:

**public generic toolchain evidence -> offline/private downstream assessment**

The workflow accepts no downstream private design, requirement, mission, audit, registry, decision, installation, or project-secret input. Its artifacts are generic environment evidence only.

## Controlled trigger and harness identity

- manual `workflow_dispatch` only;
- explicit authorization token `AUTHORIZE_CONTROLLED_NUMENV`;
- caller supplies `expected_harness_sha` as a full 40-hex reviewed commit SHA;
- existing `scripts/capture_harness_identity.ps1` must verify `expected_harness_sha == GITHUB_SHA == checked-out HEAD` before acquisition;
- the exact git commit archive and selected harness file SHA-256 values are captured in evidence.

## Runner

The controlled job uses `ubuntu-24.04`. Runner image/version, operating-system identity, Docker identity, host Python identity, CPU information, and relevant GitHub runner environment variables are captured. The host runner is provenance only; it is not the qualification Python environment.

## Immutable qualification image

Requested image:

`docker.io/library/python@sha256:67a1e1f215ccda113cfc024e8639049257e88f273898f595b61476d128d387e8`

Target platform: `linux/amd64`.

The acquisition script first records the raw registry descriptor for the frozen digest and classifies it as a multi-platform index or a single manifest. If it is an index, it deterministically selects the unique `linux/amd64` child manifest and records that child digest. It then pulls by the frozen immutable digest, records RepoDigests, image ID/config digest, full Docker inspection, target platform and saved-image SHA-256, and fails closed unless the frozen-digest relation and target platform are both proven.

## Frozen wheelhouse

Eight exact wheels are frozen by filename, direct PyPI file URL and SHA-256 in `config/generic_python_numenv_wheelhouse.csv`. Acquisition verifies every downloaded byte before it becomes a wheelhouse member.

Before any installation inside the qualification container, the entire wheelhouse is re-hashed against `config/generic_python_numenv_wheelhouse_sha256.txt`. The pip bootstrap wheel is then reverified independently immediately before consumption.

## Network-disabled installation

The qualification install uses Docker `--network none` and `--pull=never`. An outbound socket probe must fail before installation. Package installation uses only the read-only local wheelhouse:

- exact verified pip bootstrap wheel;
- `--no-index`;
- `--find-links=/wheelhouse`;
- `--only-binary=:all:`;
- `--require-hashes`.

All numerical-thread environment variables declared by policy are set to `1` before NumPy/SciPy import.

## Qualification evidence

The workflow records at least:

- exact Python version and executable SHA-256;
- complete installed package inventory and `pip check`;
- exact expected package versions;
- `numpy.show_config()`;
- SciPy configuration;
- dynamic-library linkage for representative NumPy/SciPy extension modules;
- CPU architecture and flags;
- deterministic thread-variable proof;
- wheel bytes and hashes;
- OCI/image identities and saved-image hash;
- complete evidence `SHA256SUMS.txt`.

## Artifact and transport convention

Primary evidence artifact:

`GENERIC_PYTHON_NUMENV_V1_CONTROLLED_EVIDENCE`

Transport record artifact:

`GENERIC_PYTHON_NUMENV_V1_TRANSPORT_RECORD`

The primary GitHub artifact's SHA-256 digest, artifact ID, URL, run binding and reviewed harness SHA are recorded in the separate transport record. GitHub artifact retention remains transport/storage only; downstream authority is established separately after offline ingestion and review.
