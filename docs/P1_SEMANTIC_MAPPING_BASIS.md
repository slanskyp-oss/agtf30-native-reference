# P1 semantic mapping basis

This harness maps the reviewed generic NASA AGTF30/T-MATS native output schema into controlled derivative semantic evidence while retaining raw native MAT as the authority.

## Mapping authority

The only accepted mapping contract for this tooling revision is:

- schema: `NREF_P1_SEMANTIC_MAPPING_CONTRACT_v1.0-R1`
- path: `config/p1_semantic_mapping.json`
- SHA-256: `2d81fe446a7e969ca4e21a18c79dfa9ad8ab71c73a0d4e7e23cd28bb7261102a`

The semantic exporter fails closed if the file hash or schema differs.

## Native output rules

The reviewed source schema contains exactly 68 numeric/logical `out_SS` paths. The exporter enumerates the current runtime numeric leaf set and requires exact set equality with those 68 reviewed paths: missing and additional numeric paths both fail. Scalar paths must retain exact `1x1` shape. The two solver vectors must retain exact `1x12` shape and source order. Required values must be finite.

All P1 semantic values retain their source-native units. No unit conversion, normalization, interpolation, averaging, reconstructed value, or magnitude-based unit inference is permitted.

Semantic numeric values are emitted only inside ordered records that also carry `value_shape`. No second shape-less semantic-value mirror is emitted. JSON array orientation shall not be treated as MATLAB array-shape authority after decoding; the recorded native `value_shape` is authoritative for shape review.

Raw native MAT is written independently and remains authoritative. Semantic JSON is derivative evidence only.

Each per-point semantic record carries:
- the exact reviewed mapping schema and SHA-256;
- both the reviewed source identities and the current-run `source_identity_actual.json`, with repository/commit/tag hard-identity equality enforced;
- `GITHUB_REPOSITORY`, `GITHUB_REF`, `GITHUB_WORKFLOW`, `GITHUB_SHA`, `EXPECTED_HARNESS_SHA`, Run ID and Run Attempt;
- the deterministic relative path and SHA-256 of the point's authoritative raw MAT file.

Semantic export fails closed if the controlled actual and expected harness SHA values are missing, malformed, or unequal, or if required GitHub run-binding metadata is absent.

## Component diagnostics

The exporter also records reviewed compressor and turbine diagnostics from the native `out_*mp` structures. Fields with supported source semantics are emitted with their native unit and quality class. Fields classified `NOT_PROMOTED_*` are not assigned engineering values in semantic evidence; their names and quarantine disposition are retained.

Generic map coordinates, extrapolated map regions, and source stall-margin quantities remain source-model diagnostics. They do not establish OEM-specific operability authority.

## Warning policy

The reviewed mapping retains the known CoreNoz convergence-path warning disposition associated by deterministic execution-order correlation with `SRC-PP-01`. The association is not represented as directly point-labelled warning evidence.

For the reviewed point, the semantic exporter checks the accepted final-state condition `S7.Pt > Pa`. Current-run warning occurrence itself remains subject to post-run MATLAB diary review.

## Semantic authority

Successful export uses:

`DERIVATIVE_SEMANTIC_DECK_CANDIDATE_REQUIRES_OVERSIGHT_ACCEPTANCE`

Per-point successful extraction is `SEMANTIC_EXTRACTION_PASS_CANDIDATE`. A successful CI run therefore remains a semantic-deck candidate. It does not self-issue validation or downstream engineering authority.

Native execution status and semantic extraction status are deliberately separate: a semantic parser failure does not rewrite a valid native `PASS_NATIVE_CONVERGED`; it is recorded in the semantic execution summary and still fails aggregate qualification.
