# Controlled modern C MEX compiler selection basis

For the P1-COMPAT candidate, the expected compiler family is **Microsoft Visual C++ 2022 / Visual Studio 2022 Build Tools** on the `windows-2022` runner.

## Deterministic candidate qualification

- MATLAB R2023b is the controlled MATLAB release.
- The workflow records the actual Visual Studio instances and MSVC toolset paths exposed by the runner.
- MATLAB enumerates installed supported compiler configurations with `mex.getCompilerConfigurations('C','Installed')`.
- Deterministic qualification requires **exactly one installed configuration whose `Language` is `C`**.
- That sole C configuration must match the Microsoft Visual C++ 2022 family.
- Multiple installed C configurations or an unexpected compiler family cause `COMPILER_SELECTION_FAIL`.

## Semantic compiler identity

Compiler identity is evaluated using:

- `Name`
- `Manufacturer`
- `Language`
- `Version`
- `Location`

`Location` is compared as a Windows path after separator normalization, case normalization, and removal of non-root trailing separators.

`ShortName` is a **configuration descriptor, not a hard compiler-identity field**. MATLAB defines it as text used to identify the options file for the compiler. It is recorded and compared for audit, but a `ShortName` difference alone does not establish a different compiler installation.

`MexOpt` is **configuration provenance, not compiler identity**. MATLAB defines it as the name and full path to the compiler options file. Its raw path, normalized path, existence, and file size are recorded for audit, but a `MexOpt` path change alone does not mean that the compiler family or compiler installation changed.

## Selection behavior

The harness first inspects `mex.getCompilerConfigurations('C','Selected')` without changing compiler state.

If exactly one selected C configuration already matches the sole installed candidate by semantic compiler identity:

- it is accepted directly;
- `mex -setup C` is **not** executed;
- the selection action is recorded as `PRESELECTED_ACCEPTED`.

If no selected C configuration exists, or the selected configuration does not semantically match the sole candidate:

- the harness executes the documented `mex -setup C` path once;
- it re-reads the selected C configuration;
- it requires semantic identity to match the sole installed candidate;
- a successful recovery is recorded as `MEX_SETUP_C_SELECTED`;
- unresolved ambiguity or mismatch causes `COMPILER_SELECTION_FAIL`.

More than one selected C configuration is treated as an invalid ambiguous state and fails without attempting to guess.

## Evidence

The controlled run records:

- `evidence/environment/installed_c_mex_compilers.csv`
- `evidence/environment/compiler_selection_assessment.json`
- `evidence/environment/selected_c_mex_compiler.json`
- `evidence/environment/mex_build_record.txt`

The compiler-selection assessment preserves the candidate, selected state before selection, selected state after any recovery selection, field-level semantic comparison, and `MexOpt` provenance.

No SDK emulation, compiler configuration-file editing, direct `mex -f` override, or NASA source modification is permitted.

This remains a modern-toolchain compatibility run, not a historical runtime reproduction.
