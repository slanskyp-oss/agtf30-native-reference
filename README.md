# AGTF30 native source reference harness

This repository is a **generic public propulsion-source evidence tool** for NASA AGTF30 and T-MATS. It contains no downstream vehicle design, mission, requirement, installation, or proprietary program data.

## Purpose

The controlled workflow checks out exact public NASA source identities, builds unmodified T-MATS MEX components with a declared modern compiler, executes a generic source-driven AGTF30 reference grid inside the native source envelope, and preserves raw native outputs plus execution provenance.

Primary source identities:

- NASA AGTF30: `a1521a76930df92ae5611f3454fc612a8b574cdf`
- NASA T-MATS v1.3.0: `56066ead5f461c33286425bd928ff77ed03c5244`

Primary execution classification:

**P1-COMPAT CANDIDATE — NATIVE SOURCE / MODERN TOOLCHAIN COMPATIBILITY RUN**

This is not a historical MATLAB-2015a runtime reproduction.

## Public-content boundary

Repository content is allowlist-only and limited to public NASA source identities, generic source-native reference conditions, CI/build/run tooling, execution provenance, generic raw native outputs, schema inventories, reviewed generic semantic mapping, derivative semantic-deck candidate evidence, and integrity manifests. The workflow has no path, token, secret, checkout, or dependency for downstream private engineering repositories.

Information flow is one-way: **public NASA source → generic evidence artifact → offline/private downstream assessment**.

## Workflows

### Development smoke

`.github/workflows/native-agtf30-smoke.yml`

Push and pull-request triggers are permitted. Output is explicitly **NON-CONTROLLED DEVELOPMENT ARTIFACT** and is not authoritative source evidence.

### Controlled P1 acquisition

`.github/workflows/native-agtf30-v130-controlled.yml`

This workflow is `workflow_dispatch` only and requires both:

- explicit `AUTHORIZE_CONTROLLED_P1` authorization; and
- `expected_harness_sha`, the reviewed 40-hex Git commit SHA of the exact public harness.

The run stops before NASA source checkout if `GITHUB_SHA` or checked-out `HEAD` does not equal `expected_harness_sha`. The reviewed full Git commit SHA is therefore the canonical harness authority.

The controlled job records repository/ref/workflow/run identity, runner image metadata, Python identity, MATLAB release, compiler, exact NASA commits, source cleanliness, raw outputs and artifact digest.

## Action runtime policy

Controlled and smoke workflows pin all GitHub Actions to full immutable commit SHAs. The selected checkout, artifact-upload and MathWorks actions are Node-24-native at the registered commits; human-readable release tags are comments/metadata only.

## MATLAB licensing

The intended execution path is a **public GitHub repository on a GitHub-hosted runner** using official MathWorks MATLAB Actions with MATLAB R2023b and Simulink. Both the short preflight and the authoritative native acquisition execute through the pinned Run MATLAB Command action. The workflow does not request MATLAB Coder or MATLAB Compiler.

Repository visibility is part of the tooling basis. Changing the repository to private requires a separate licensing/tooling review before controlled use.

## Compiler policy

The controlled R2023b run requires the Microsoft Visual C++ 2022 / Visual Studio 2022 Build Tools C MEX family. The workflow enumerates installed MATLAB compiler configurations and requires exactly one supported C configuration. That sole C configuration must be Microsoft Visual C++ 2022. The harness first inspects the currently selected C configuration and accepts it without changing compiler state when it matches the sole candidate by semantic compiler identity. The documented `mex -setup C` path is used only as a recovery selection path when the selected C configuration is missing or semantically mismatched. Ambiguous or unexpected compiler environments fail rather than silently falling back. `ShortName` and `MexOpt` are retained as configuration descriptor/provenance evidence and are not hard compiler-identity fields.

## Dependency / Cantera policy

Before build, the exact detached AGTF30 checkout is inspected for T-MATS library references and Cantera-enabled execution-path markers. If Cantera is required, the run stops before build. No substitute Cantera version is installed automatically.

## Source cleanliness

Tracked NASA source must be clean before build and after run. Generated/untracked MEX and build products are recorded separately and do not qualify as tracked-source edits.

## Reference grid

`config/reference_grid.csv` contains 18 intentionally **source-driven and generic** points inside the native AGTF30 source envelope. It uses only TAKEOFF, CLIMB, CRUISE and PART_POWER groups.

For every point, requested altitude, Mach, dT and PLA are compared with source-actual setup values using predeclared tolerances. A source clamp/change is rejected rather than accepted as the requested reference. Point failures do not abort the remaining independent grid; the aggregate acquisition fails after the complete grid if any mandatory point fails.

## Timeout policy

The whole controlled job timeout is 240 minutes. The authoritative native acquisition is itself a pinned `matlab-actions/run-command` step with GitHub `timeout-minutes: 180`, leaving a declared 60-minute nominal margin for source-cleanliness checks, status finalization, evidence hashing/packaging, artifact upload and transport recording. A generic failed MATLAB action is classified `MATLAB_ACTION_EXECUTION_FAIL` unless available evidence supports a more specific class. `NATIVE_STEP_TIMEOUT_TOOLING_FAIL` is used only when run metadata explicitly establishes timeout; neither action failure nor timeout is engine nonconvergence.

## Evidence authority

Raw MAT files containing native `out_*`, `MWS`, requested input and source-setup state are the authoritative generic-source evidence. Parsed numeric inventories remain derivative diagnostics. A reviewed generic semantic mapping contract is hash-bound by the semantic exporter; semantic JSON produced from the same controlled native points is derivative **semantic-deck candidate evidence** and requires downstream Oversight acceptance before semantic P1 authority is established.

GitHub artifact retention is transport/storage only. A qualifying artifact should be downloaded, SHA-256 verified, and preserved in controlled downstream storage together with its run and harness provenance.


## Reviewed semantic mapping

`config/p1_semantic_mapping.json` is the reviewed generic source-semantic contract for this tooling revision. `scripts/nref_export_semantic_p1.m` fails closed on mapping hash/schema mismatch, missing paths, wrong scalar/vector shape, non-finite required values, disallowed transformations, component-schema mismatch, unsupported promoted component data, or controlled harness/run-binding mismatch.

All 68 reviewed `out_SS` mappings retain source-native units. Runtime numeric `out_SS` paths must match the reviewed 68-path set exactly; missing or additional numeric paths fail. The 12-element solver vectors retain source order and carry explicit native `value_shape`; JSON array orientation is not treated as MATLAB shape authority after decoding. Each per-point semantic record carries reviewed and current-run source identity with hard commit binding, harness/run binding, and the relative path plus SHA-256 of its authoritative raw MAT. Raw MAT remains authoritative.

Per-point semantic success is `SEMANTIC_EXTRACTION_PASS_CANDIDATE`. Native and semantic point statuses are separate: semantic extraction failure does not overwrite a valid native convergence PASS, but it does fail aggregate semantic qualification. Aggregate controlled success is only a semantic-deck candidate requiring downstream Oversight artifact acceptance.

## Compatibility branch

The T-MATS v1.3.3 compatibility workflow remains disabled for the primary v1.3.0 attempt. If exact v1.3.0 cannot build/run unmodified under the controlled modern toolchain, preserve the failed evidence and review a separately identified v1.3.3 compatibility branch before use.
